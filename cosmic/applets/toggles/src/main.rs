//! Session toggles in the panel (the Omarchy indicators and pneuma.controls): stay awake and
//! eye breaks. The bar icon shows the first active toggle; the popup lists labelled switches.
//! Each toggle is owned by its script (cosmic/bin/pneuma-stay-awake, pneuma-eyes) and read back
//! from the state file that script keeps, so the launcher rows and shortcuts stay in step.

use std::path::PathBuf;
use std::process::Command;
use std::time::Duration;

use cosmic::iced::platform_specific::shell::wayland::commands::popup::{destroy_popup, get_popup};
use cosmic::iced::{Limits, Subscription, time, window::Id};
use cosmic::prelude::*;
use cosmic::widget;

const APP_ID: &str = "dev.pneuma.Toggles";
const POLL: Duration = Duration::from_secs(2);

fn main() -> cosmic::iced::Result {
    cosmic::applet::run::<Applet>(())
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Toggle {
    StayAwake,
    EyeBreaksPaused,
}

impl Toggle {
    const ALL: [Toggle; 2] = [Toggle::StayAwake, Toggle::EyeBreaksPaused];

    fn label(self) -> &'static str {
        match self {
            Toggle::StayAwake => "Stay awake",
            Toggle::EyeBreaksPaused => "Pause eye breaks",
        }
    }

    fn icon(self) -> &'static str {
        match self {
            Toggle::StayAwake => "display-brightness-symbolic",
            Toggle::EyeBreaksPaused => "view-conceal-symbolic",
        }
    }

    /// The file the owning script leaves behind while the toggle is on.
    fn flag(self, state_dir: &std::path::Path) -> PathBuf {
        match self {
            Toggle::StayAwake => state_dir.join("pneuma/stay-awake.screen_off_time"),
            Toggle::EyeBreaksPaused => state_dir.join("pneuma/safeeyes-paused"),
        }
    }

    fn command(self, on: bool) -> (&'static str, &'static str) {
        match (self, on) {
            (Toggle::StayAwake, true) => ("pneuma-stay-awake", "on"),
            (Toggle::StayAwake, false) => ("pneuma-stay-awake", "off"),
            (Toggle::EyeBreaksPaused, true) => ("pneuma-eyes", "pause"),
            (Toggle::EyeBreaksPaused, false) => ("pneuma-eyes", "resume"),
        }
    }
}

struct Applet {
    core: cosmic::Core,
    popup: Option<Id>,
    state_dir: PathBuf,
    bin_dir: PathBuf,
    active: [bool; 2],
}

#[derive(Debug, Clone)]
enum Message {
    TogglePopup,
    PopupClosed(Id),
    Poll,
    Set(Toggle, bool),
}

impl Applet {
    fn poll(&mut self) {
        for (slot, toggle) in self.active.iter_mut().zip(Toggle::ALL) {
            *slot = toggle.flag(&self.state_dir).exists();
        }
    }

    fn is_on(&self, toggle: Toggle) -> bool {
        self.active[Toggle::ALL.iter().position(|t| *t == toggle).unwrap_or(0)]
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
        let home = PathBuf::from(std::env::var_os("HOME").unwrap_or_default());
        let state_dir = std::env::var_os("XDG_STATE_HOME").map_or_else(|| home.join(".local/state"), PathBuf::from);
        let mut applet = Self { core, popup: None, state_dir, bin_dir: home.join(".local/bin"), active: [false; 2] };
        applet.poll();
        (applet, Task::none())
    }

    fn on_close_requested(&self, id: Id) -> Option<Message> {
        Some(Message::PopupClosed(id))
    }

    fn view(&self) -> Element<'_, Message> {
        let icon = Toggle::ALL
            .iter()
            .find(|t| self.is_on(**t))
            .map_or("view-more-symbolic", |t| t.icon());
        self.core.applet.icon_button(icon).on_press(Message::TogglePopup).into()
    }

    fn view_window(&self, _id: Id) -> Element<'_, Message> {
        let mut list = widget::list_column();
        for toggle in Toggle::ALL {
            let switch = widget::toggler(self.is_on(toggle)).on_toggle(move |on| Message::Set(toggle, on));
            list = list.add(widget::settings::item(toggle.label(), switch));
        }
        self.core.applet.popup_container(list).into()
    }

    fn subscription(&self) -> Subscription<Message> {
        time::every(POLL).map(|_| Message::Poll)
    }

    fn update(&mut self, message: Message) -> Task<cosmic::Action<Message>> {
        match message {
            Message::TogglePopup => {
                return match self.popup.take() {
                    Some(id) => destroy_popup(id),
                    None => {
                        self.poll();
                        let id = Id::unique();
                        self.popup = Some(id);
                        let mut settings = self.core.applet.get_popup_settings(
                            self.core.main_window_id().unwrap(),
                            id,
                            None,
                            None,
                            None,
                        );
                        settings.positioner.size_limits = Limits::NONE.min_width(260.0).max_width(360.0).min_height(60.0).max_height(400.0);
                        get_popup(settings)
                    }
                };
            }
            Message::PopupClosed(id) => {
                if self.popup == Some(id) {
                    self.popup = None;
                }
            }
            Message::Poll => self.poll(),
            Message::Set(toggle, on) => {
                let (script, verb) = toggle.command(on);
                // The script writes the flag; the next poll confirms. Reaped in a thread so no zombie.
                if let Ok(mut child) = Command::new(self.bin_dir.join(script)).arg(verb).spawn() {
                    std::thread::spawn(move || child.wait());
                }
                let index = Toggle::ALL.iter().position(|t| *t == toggle).unwrap_or(0);
                self.active[index] = on;
            }
        }
        Task::none()
    }

    fn style(&self) -> Option<cosmic::iced::theme::Style> {
        Some(cosmic::applet::style())
    }
}
