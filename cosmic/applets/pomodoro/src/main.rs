//! Pomodoro panel applet (the pneuma.pomodoro bar widget). Idle is an alarm glyph; a live phase
//! puts `mm:ss` on the bar. Left click opens the panel, middle click starts or pauses, right click
//! skips the phase. A running phase is a wall-clock deadline, never a counter, so suspend, a slow
//! tick and a panel restart all agree on the time left. Breaks start on their own; focus always
//! waits for a deliberate start. A ticking focus phase holds Do Not Disturb unless it was on already.
//! State and the session lengths live in ~/.local/state/pneuma/pomodoro.json.

use std::path::PathBuf;
use std::process::Command;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use cosmic::cosmic_config::{self, ConfigGet, ConfigSet};
use cosmic::iced::platform_specific::shell::wayland::commands::popup::{destroy_popup, get_popup};
use cosmic::iced::{Alignment, Length, Limits, Subscription, time, window::Id};
use cosmic::prelude::*;
use cosmic::widget::{self, autosize, icon, mouse_area};
use serde::{Deserialize, Serialize};
use std::sync::LazyLock;

const APP_ID: &str = "dev.pneuma.Pomodoro";
const MINUTE_STEP: u32 = 5;
const MIN_MINUTES: u32 = 1;
const MAX_MINUTES: u32 = 180;
// Distinct chimes on purpose: the ear should tell focus-over from break-over without looking.
const FOCUS_END_SOUND: &str = "/usr/share/sounds/freedesktop/stereo/service-login.oga";
const BREAK_END_SOUND: &str = "/usr/share/sounds/gnome/default/alerts/string.ogg";
static AUTOSIZE_ID: LazyLock<widget::Id> = LazyLock::new(|| widget::Id::new("pneuma-pomodoro"));

fn main() -> cosmic::iced::Result {
    cosmic::applet::run::<Applet>(())
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
enum Phase {
    #[default]
    Idle,
    Focus,
    ShortBreak,
    LongBreak,
}

impl Phase {
    fn is_break(self) -> bool {
        matches!(self, Phase::ShortBreak | Phase::LongBreak)
    }

    fn label(self) -> &'static str {
        match self {
            Phase::Idle => "READY",
            Phase::Focus => "FOCUS",
            Phase::ShortBreak => "SHORT BREAK",
            Phase::LongBreak => "LONG BREAK",
        }
    }
}

/// Everything that survives a panel restart, in the shape the Omarchy widget wrote.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
struct State {
    phase: Phase,
    running: bool,
    /// Epoch milliseconds; authoritative while running.
    ends_at: u64,
    /// Remaining milliseconds while paused or ready.
    paused_ms: u64,
    total_ms: u64,
    completed_in_cycle: u32,
    dnd_held: bool,
    work_minutes: u32,
    break_minutes: u32,
    long_break_minutes: u32,
    cycles_per_long: u32,
    focus_dnd: bool,
}

impl Default for State {
    fn default() -> Self {
        Self {
            phase: Phase::Idle,
            running: false,
            ends_at: 0,
            paused_ms: 0,
            total_ms: 0,
            completed_in_cycle: 0,
            dnd_held: false,
            work_minutes: 10,
            break_minutes: 5,
            long_break_minutes: 15,
            cycles_per_long: 4,
            focus_dnd: true,
        }
    }
}

impl State {
    fn minutes_for(&self, phase: Phase) -> u32 {
        match phase {
            Phase::ShortBreak => self.break_minutes,
            Phase::LongBreak => self.long_break_minutes,
            _ => self.work_minutes,
        }
    }

    fn minutes_mut(&mut self, phase: Phase) -> &mut u32 {
        match phase {
            Phase::ShortBreak => &mut self.break_minutes,
            Phase::LongBreak => &mut self.long_break_minutes,
            _ => &mut self.work_minutes,
        }
    }

    /// What follows `finished`, with the finished focus already counted.
    fn next_phase(&self, finished: Phase) -> Phase {
        if finished != Phase::Focus {
            Phase::Focus
        } else if self.completed_in_cycle >= self.cycles_per_long {
            Phase::LongBreak
        } else {
            Phase::ShortBreak
        }
    }

    fn remaining_ms(&self, now: u64) -> u64 {
        if self.running { self.ends_at.saturating_sub(now) } else { self.paused_ms }
    }

    fn begin_phase(&mut self, next: Phase, auto_start: bool, now: u64) {
        self.phase = next;
        self.total_ms = u64::from(self.minutes_for(next)) * 60_000;
        self.paused_ms = self.total_ms;
        self.ends_at = if auto_start { now + self.total_ms } else { 0 };
        self.running = auto_start;
    }

    /// Roll the finished phase into the next one. Returns the finished phase and the next.
    fn advance(&mut self, now: u64) -> (Phase, Phase) {
        let finished = self.phase;
        if finished == Phase::Focus {
            self.completed_in_cycle = (self.completed_in_cycle + 1).min(self.cycles_per_long);
        } else if finished == Phase::LongBreak {
            self.completed_in_cycle = 0;
        }
        let next = self.next_phase(finished);
        self.begin_phase(next, next.is_break(), now);
        (finished, next)
    }

    /// Re-length the phase on the clock, keeping the time already spent.
    fn retarget(&mut self, phase: Phase, now: u64) {
        if self.phase != phase || self.total_ms == 0 {
            return;
        }
        let target = u64::from(self.minutes_for(phase)) * 60_000;
        let delta = i128::from(target) - i128::from(self.total_ms);
        self.total_ms = target;
        if self.running {
            self.ends_at = (i128::from(self.ends_at) + delta).max(i128::from(now)) as u64;
        } else {
            self.paused_ms = (i128::from(self.paused_ms) + delta).max(0) as u64;
        }
    }
}

fn now_ms() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map_or(0, |d| d.as_millis() as u64)
}

/// mm:ss rounded up, so a fresh phase reads its full length and the last live second reads 00:01.
fn clock(ms: u64) -> String {
    let total = ms.div_ceil(1000);
    format!("{:02}:{:02}", total / 60, total % 60)
}

/// Walk to the neighbouring multiple of MINUTE_STEP, so an odd length snaps onto the grid.
fn step_minutes(current: u32, up: bool) -> u32 {
    let stepped = if up {
        (current / MINUTE_STEP + 1) * MINUTE_STEP
    } else {
        (current.div_ceil(MINUTE_STEP)).saturating_sub(1) * MINUTE_STEP
    };
    stepped.clamp(MIN_MINUTES, MAX_MINUTES)
}

fn cycle_dots(completed: u32, per_long: u32) -> String {
    (0..per_long).map(|i| if i < completed { "●" } else { "○" }).collect::<Vec<_>>().join(" ")
}

fn announcement(finished: Phase, next: Phase, state: &State) -> String {
    if next.is_break() {
        let label = if next == Phase::LongBreak { "long break" } else { "break" };
        format!("Focus done — {} minute {label} started", state.minutes_for(next))
    } else if finished == Phase::LongBreak {
        "Long break over — ready when you are".to_owned()
    } else {
        "Break over — ready to focus".to_owned()
    }
}

fn detached(program: &str, args: &[&str]) {
    if let Ok(mut child) = Command::new(program).args(args).spawn() {
        std::thread::spawn(move || child.wait());
    }
}

fn state_path() -> PathBuf {
    let state = std::env::var_os("XDG_STATE_HOME").map(PathBuf::from).unwrap_or_else(|| {
        PathBuf::from(std::env::var_os("HOME").unwrap_or_default()).join(".local/state")
    });
    state.join("pneuma/pomodoro.json")
}

fn load_state(path: &PathBuf) -> State {
    std::fs::read(path).ok().and_then(|bytes| serde_json::from_slice(&bytes).ok()).unwrap_or_default()
}

fn save_state(path: &PathBuf, state: &State) {
    let Ok(json) = serde_json::to_vec_pretty(state) else { return };
    if let Some(dir) = path.parent() {
        let _ = std::fs::create_dir_all(dir);
    }
    let partial = path.with_extension("json.partial");
    if std::fs::write(&partial, json).is_ok() {
        let _ = std::fs::rename(&partial, path);
    }
}

/// cosmic-notifications' own key, so the toggle in its applet and this hold agree.
fn dnd_config() -> Option<cosmic_config::Config> {
    cosmic_config::Config::new("com.system76.CosmicNotifications", 1).ok()
}

struct Applet {
    core: cosmic::Core,
    popup: Option<Id>,
    tune: bool,
    state: State,
    path: PathBuf,
    now: u64,
}

#[derive(Debug, Clone)]
enum Message {
    TogglePopup,
    PopupClosed(Id),
    Tick,
    StartPause,
    Skip,
    Reset,
    ToggleTune,
    Adjust(Phase, bool),
}

impl Applet {
    fn save(&self) {
        save_state(&self.path, &self.state);
    }

    fn sync_dnd(&mut self) {
        let focus_ticking = self.state.running && self.state.phase == Phase::Focus;
        let Some(config) = dnd_config() else { return };
        if focus_ticking && self.state.focus_dnd {
            let already_on = config.get::<bool>("do_not_disturb").unwrap_or(false);
            if !self.state.dnd_held && !already_on {
                let _ = config.set("do_not_disturb", true);
                self.state.dnd_held = true;
            }
        } else if self.state.dnd_held {
            self.state.dnd_held = false;
            let _ = config.set("do_not_disturb", false);
        }
    }

    fn start_pause(&mut self) {
        self.now = now_ms();
        let state = &mut self.state;
        if state.running {
            state.paused_ms = state.ends_at.saturating_sub(self.now);
            state.ends_at = 0;
            state.running = false;
        } else if state.phase == Phase::Idle {
            state.begin_phase(Phase::Focus, true, self.now);
        } else if state.paused_ms > 0 {
            state.ends_at = self.now + state.paused_ms;
            state.running = true;
        }
    }

    fn advance(&mut self, notify: bool) {
        self.now = now_ms();
        let (finished, next) = self.state.advance(self.now);
        if notify {
            let body = announcement(finished, next, &self.state);
            detached("notify-send", &["-a", "Pomodoro", "Pomodoro", &body]);
            let sound = if finished == Phase::Focus { FOCUS_END_SOUND } else { BREAK_END_SOUND };
            if std::path::Path::new(sound).exists() {
                detached("pw-play", &[sound]);
            }
        }
    }

    fn open_popup(&mut self) -> Task<cosmic::Action<Message>> {
        let id = Id::unique();
        self.popup = Some(id);
        let mut settings = self.core.applet.get_popup_settings(
            self.core.main_window_id().unwrap(),
            id,
            None,
            None,
            None,
        );
        settings.positioner.size_limits = Limits::NONE.min_width(280.0).max_width(360.0).min_height(120.0).max_height(600.0);
        get_popup(settings)
    }

    fn duration_row(&self, label: &'static str, phase: Phase) -> Element<'_, Message> {
        let minutes = self.state.minutes_for(phase);
        widget::row::with_capacity(4)
            .align_y(Alignment::Center)
            .spacing(8)
            .push(widget::text::body(label).width(Length::Fill))
            .push(widget::button::icon(icon::from_name("list-remove-symbolic")).on_press(Message::Adjust(phase, false)))
            .push(widget::text::body(format!("{minutes} min")))
            .push(widget::button::icon(icon::from_name("list-add-symbolic")).on_press(Message::Adjust(phase, true)))
            .into()
    }
}

impl cosmic::Application for Applet {
    type Executor = cosmic::executor::Default;
    type Flags = ();
    type Message = Message;
    const APP_ID: &'static str = APP_ID;

    fn core(&self) -> &cosmic::Core {
        &self.core
    }

    fn core_mut(&mut self) -> &mut cosmic::Core {
        &mut self.core
    }

    fn init(core: cosmic::Core, _flags: ()) -> (Self, Task<cosmic::Action<Message>>) {
        let path = state_path();
        let now = now_ms();
        let mut state = load_state(&path);
        // A phase that elapsed while the panel was down settles quietly on what should be showing.
        if state.running && state.ends_at <= now {
            state.advance(now);
            if state.running && state.ends_at <= now {
                state.begin_phase(state.phase, false, now);
            }
        }
        let mut applet = Self { core, popup: None, tune: false, state, path, now };
        applet.sync_dnd();
        applet.save();
        (applet, Task::none())
    }

    fn on_close_requested(&self, id: Id) -> Option<Message> {
        Some(Message::PopupClosed(id))
    }

    fn view(&self) -> Element<'_, Message> {
        let state = &self.state;
        let content: Element<'_, Message> = if state.phase == Phase::Idle {
            self.core.applet.icon_button("alarm-symbolic").on_press(Message::TogglePopup).into()
        } else {
            let mut label = format!(
                "{} {}",
                if state.phase.is_break() { "break" } else { "focus" },
                clock(state.remaining_ms(self.now))
            );
            if !state.running {
                label.push_str(" · paused");
            }
            let text = self.core.applet.text(label);
            let button = self.core.applet.text_button(text, Message::TogglePopup);
            autosize::autosize(button, AUTOSIZE_ID.clone()).into()
        };
        mouse_area(content)
            .on_middle_press(Message::StartPause)
            .on_right_press(Message::Skip)
            .into()
    }

    fn view_window(&self, _id: Id) -> Element<'_, Message> {
        let state = &self.state;
        let header = widget::row::with_capacity(4)
            .push(widget::text::heading(state.phase.label()).width(Length::Fill))
            .push(widget::text::body(cycle_dots(state.completed_in_cycle, state.cycles_per_long)));
        let countdown = widget::text::title1(clock(if state.phase == Phase::Idle {
            u64::from(state.work_minutes) * 60_000
        } else {
            state.remaining_ms(self.now)
        }));
        let start_label = if state.running { "Pause" } else if state.phase == Phase::Idle { "Start" } else { "Resume" };
        let mut transport = widget::row::with_capacity(4)
            .spacing(8)
            .push(widget::button::suggested(start_label).on_press(Message::StartPause));
        if state.phase != Phase::Idle {
            transport = transport
                .push(widget::button::standard("Skip").on_press(Message::Skip))
                .push(widget::button::standard("Reset").on_press(Message::Reset));
        }
        transport = transport.push(cosmic::iced::widget::Space::new().width(Length::Fill)).push(
            widget::button::icon(icon::from_name("emblem-system-symbolic")).on_press(Message::ToggleTune),
        );
        let mut content = widget::column::with_capacity(8)
            .spacing(12)
            .padding([12, 16])
            .push(header)
            .push(widget::container(countdown).width(Length::Fill).align_x(Alignment::Center))
            .push(transport);
        if self.tune {
            content = content
                .push(widget::divider::horizontal::default())
                .push(self.duration_row("Focus", Phase::Focus))
                .push(self.duration_row("Break", Phase::ShortBreak))
                .push(self.duration_row("Long break", Phase::LongBreak));
        }
        self.core.applet.popup_container(content).into()
    }

    fn subscription(&self) -> Subscription<Message> {
        if self.state.running {
            time::every(Duration::from_secs(1)).map(|_| Message::Tick)
        } else {
            Subscription::none()
        }
    }

    fn update(&mut self, message: Message) -> Task<cosmic::Action<Message>> {
        eprintln!("DEBUG pomodoro message {message:?}");
        match message {
            Message::TogglePopup => {
                return match self.popup.take() {
                    Some(id) => destroy_popup(id),
                    None => self.open_popup(),
                };
            }
            Message::PopupClosed(id) => {
                if self.popup == Some(id) {
                    self.popup = None;
                }
            }
            Message::Tick => {
                self.now = now_ms();
                if self.state.running && self.state.ends_at <= self.now {
                    self.advance(true);
                }
            }
            Message::StartPause => self.start_pause(),
            Message::Skip => {
                if self.state.phase != Phase::Idle {
                    self.advance(false);
                }
            }
            Message::Reset => {
                self.state.phase = Phase::Idle;
                self.state.running = false;
                self.state.ends_at = 0;
                self.state.paused_ms = 0;
                self.state.total_ms = 0;
                self.state.completed_in_cycle = 0;
            }
            Message::ToggleTune => self.tune = !self.tune,
            Message::Adjust(phase, up) => {
                let minutes = self.state.minutes_mut(phase);
                *minutes = step_minutes(*minutes, up);
                self.now = now_ms();
                self.state.retarget(phase, self.now);
            }
        }
        self.sync_dnd();
        self.save();
        Task::none()
    }

    fn style(&self) -> Option<cosmic::iced::theme::Style> {
        Some(cosmic::applet::style())
    }
}
