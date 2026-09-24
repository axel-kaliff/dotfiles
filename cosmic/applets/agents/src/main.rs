//! AI coding subscriptions in the panel (the akaliff.agents bar widget): one mark, one popup.
//! Display only: it draws the records `agent-usage-update` writes to
//! ~/.local/state/pneuma/agents/usage/<id>.json (one collector per agent, vendored in cosmic/bin)
//! and runs that command every 15 minutes and on right click. A provider shows once it has
//! recorded usage; the mark turns red when any allowance is at 90 % or more.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::process::Command;
use std::str::FromStr;
use std::time::Duration;

use cosmic::iced::platform_specific::shell::wayland::commands::popup::{destroy_popup, get_popup};
use cosmic::iced::{Length, Limits, Subscription, time, window::Id};
use cosmic::prelude::*;
use cosmic::widget::{self, icon, mouse_area};
use serde::Deserialize;

const APP_ID: &str = "dev.pneuma.Agents";
const REFRESH: Duration = Duration::from_secs(900);
const POLL: Duration = Duration::from_secs(30);
const ALARM_AT: f64 = 0.9;
/// Collectors that stay off, as `providers.codex.enabled = false` did in shell.json.
const DISABLED_PROVIDERS: [&str; 1] = ["codex"];
const MARK: &[u8] = include_bytes!("../resources/mark.svg");
const MARK_ALARM: &[u8] = include_bytes!("../resources/mark-alarm.svg");

fn main() -> cosmic::iced::Result {
    cosmic::applet::run::<Applet>(())
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase", default)]
struct Record {
    id: String,
    name: String,
    tier_label: String,
    usage_status_text: String,
    auth_help_text: String,
    limits: Vec<Limit>,
    recent_days: Vec<Day>,
    model_usage: BTreeMap<String, ModelUsage>,
    balance: Option<Balance>,
    today_prompts: f64,
    today_sessions: f64,
    updated_at: String,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase", default)]
struct Limit {
    label: String,
    /// A fraction: 0.9 is ninety percent.
    percent: f64,
    resets_at: Option<String>,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase", default)]
struct Day {
    date: String,
    /// Tokens, despite the legacy name the collectors kept for synced snapshots.
    message_count: f64,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase", default)]
struct ModelUsage {
    input_tokens: f64,
    output_tokens: f64,
    cache_read_input_tokens: f64,
    cache_creation_input_tokens: f64,
}

impl ModelUsage {
    fn total(&self) -> f64 {
        self.input_tokens + self.output_tokens + self.cache_read_input_tokens + self.cache_creation_input_tokens
    }
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase", default)]
struct Balance {
    remaining: f64,
    funded: f64,
    spent: f64,
    currency: String,
}

impl Record {
    fn has_usage(&self) -> bool {
        !self.limits.is_empty()
            || self.balance.is_some()
            || self.recent_days.iter().any(|d| d.message_count > 0.0)
            || !self.model_usage.is_empty()
    }

    fn worst_limit(&self) -> f64 {
        self.limits.iter().map(|l| l.percent).fold(0.0, f64::max)
    }
}

fn state_dir() -> PathBuf {
    std::env::var_os("XDG_STATE_HOME").map(PathBuf::from).unwrap_or_else(|| {
        PathBuf::from(std::env::var_os("HOME").unwrap_or_default()).join(".local/state")
    })
}

fn load_records(dir: &PathBuf) -> Vec<Record> {
    let Ok(entries) = std::fs::read_dir(dir) else { return Vec::new() };
    let mut records: Vec<Record> = entries
        .flatten()
        .filter(|e| e.path().extension().is_some_and(|x| x == "json"))
        .filter_map(|e| std::fs::read(e.path()).ok())
        .filter_map(|bytes| serde_json::from_slice::<Record>(&bytes).ok())
        .filter(|r| !DISABLED_PROVIDERS.contains(&r.id.as_str()) && r.has_usage())
        .collect();
    records.sort_by(|a, b| a.id.cmp(&b.id));
    records
}

fn tokens(n: f64) -> String {
    if n >= 1e9 {
        format!("{:.1}B", n / 1e9)
    } else if n >= 1e6 {
        format!("{:.1}M", n / 1e6)
    } else if n >= 1e3 {
        format!("{:.0}k", n / 1e3)
    } else {
        format!("{n:.0}")
    }
}

fn money(amount: f64, currency: &str) -> String {
    if currency == "USD" { format!("${amount:.2}") } else { format!("{amount:.2} {currency}") }
}

/// "resets in 2h 15m", or the raw value when it is not a timestamp.
fn resets_in(value: &str) -> String {
    let Ok(at) = jiff::Timestamp::from_str(value) else { return format!("resets {value}") };
    let left = at.as_second() - jiff::Timestamp::now().as_second();
    if left <= 0 {
        return "resets now".to_owned();
    }
    let (days, hours, minutes) = (left / 86_400, (left % 86_400) / 3_600, (left % 3_600) / 60);
    if days > 0 { format!("resets in {days}d {hours}h") } else { format!("resets in {hours}h {minutes:02}m") }
}

fn weekday(date: &str) -> String {
    jiff::civil::Date::from_str(date)
        .map(|d| format!("{:?}", d.weekday()).chars().take(3).collect())
        .unwrap_or_else(|_| date.to_owned())
}

fn detached(program: PathBuf, args: &[&str]) {
    if let Ok(mut child) = Command::new(program).args(args).spawn() {
        std::thread::spawn(move || child.wait());
    }
}

struct Applet {
    core: cosmic::Core,
    popup: Option<Id>,
    usage_dir: PathBuf,
    updater: PathBuf,
    records: Vec<Record>,
    selected: usize,
}

#[derive(Debug, Clone)]
enum Message {
    TogglePopup,
    PopupClosed(Id),
    Reload,
    Refresh,
    Select(usize),
}

impl Applet {
    fn refresh(&self) {
        let mut args = vec!["--limits-only"];
        for id in DISABLED_PROVIDERS {
            args.extend(["--except", id]);
        }
        detached(self.updater.clone(), &args);
    }

    fn alarming(&self) -> bool {
        self.records.iter().any(|r| r.worst_limit() >= ALARM_AT)
    }

    fn meter_row<'a>(label: String, value: String, fraction: f32, caption: Option<String>) -> Element<'a, Message> {
        let mut column = widget::column::with_capacity(3).spacing(4).push(
            widget::row::with_capacity(2)
                .push(widget::text::body(label).width(Length::Fill))
                .push(widget::text::body(value)),
        );
        column = column.push(cosmic::iced::widget::progress_bar(0.0..=1.0, fraction.clamp(0.0, 1.0)).girth(6.0));
        if let Some(caption) = caption {
            column = column.push(widget::text::caption(caption));
        }
        column.into()
    }

    fn section<'a>(title: &'static str, rows: Vec<Element<'a, Message>>) -> Element<'a, Message> {
        let mut column = widget::column::with_capacity(rows.len() + 1).spacing(8).push(widget::text::caption_heading(title));
        for row in rows {
            column = column.push(row);
        }
        column.into()
    }

    fn provider_view<'a>(&'a self, record: &'a Record) -> Element<'a, Message> {
        let mut column = widget::column::with_capacity(6).spacing(16);
        let status = if !record.usage_status_text.is_empty() {
            record.usage_status_text.clone()
        } else if record.limits.is_empty() && !record.auth_help_text.is_empty() {
            record.auth_help_text.clone()
        } else {
            record.tier_label.clone()
        };
        column = column.push(
            widget::column::with_capacity(2).push(widget::text::title3(record.name.as_str())).push(widget::text::caption(status)),
        );
        if !record.limits.is_empty() {
            let rows = record
                .limits
                .iter()
                .map(|l| {
                    Self::meter_row(
                        l.label.clone(),
                        format!("{:.0}%", l.percent * 100.0),
                        l.percent as f32,
                        l.resets_at.as_deref().map(resets_in),
                    )
                })
                .collect();
            column = column.push(Self::section("LIMITS", rows));
        }
        if let Some(balance) = &record.balance {
            let fraction = if balance.funded > 0.0 { (balance.remaining / balance.funded) as f32 } else { 0.0 };
            let row = Self::meter_row(
                "Prepaid credits".to_owned(),
                money(balance.remaining, &balance.currency),
                fraction,
                Some(format!("{} funded · {} spent", money(balance.funded, &balance.currency), money(balance.spent, &balance.currency))),
            );
            column = column.push(Self::section("BALANCE", vec![row]));
        }
        let busiest = record.recent_days.iter().map(|d| d.message_count).fold(0.0, f64::max);
        if busiest > 0.0 {
            let last = record.recent_days.len().saturating_sub(1);
            let rows = record
                .recent_days
                .iter()
                .enumerate()
                .map(|(i, d)| {
                    let label = if i == last {
                        format!("Today · {:.0} prompts · {:.0} sessions", record.today_prompts, record.today_sessions)
                    } else {
                        weekday(&d.date)
                    };
                    Self::meter_row(label, tokens(d.message_count), (d.message_count / busiest) as f32, None)
                })
                .collect();
            column = column.push(Self::section("TOKENS BY DAY", rows));
        }
        let heaviest = record.model_usage.values().map(ModelUsage::total).fold(0.0, f64::max);
        if heaviest > 0.0 {
            let mut models: Vec<(&String, &ModelUsage)> = record.model_usage.iter().collect();
            models.sort_by(|a, b| b.1.total().total_cmp(&a.1.total()));
            let rows = models
                .into_iter()
                .map(|(model, usage)| {
                    Self::meter_row(
                        model.clone(),
                        tokens(usage.total()),
                        (usage.total() / heaviest) as f32,
                        Some(format!(
                            "in {} · out {} · cache {}",
                            tokens(usage.input_tokens),
                            tokens(usage.output_tokens),
                            tokens(usage.cache_read_input_tokens + usage.cache_creation_input_tokens)
                        )),
                    )
                })
                .collect();
            column = column.push(Self::section("TOKENS BY MODEL", rows));
        }
        let updated = record.updated_at.get(11..16).unwrap_or("").to_owned();
        column = column.push(widget::text::caption(format!("updated {updated} UTC · right-click the mark to refresh")));
        column.into()
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
        let usage_dir = state_dir().join("pneuma/agents/usage");
        let updater = PathBuf::from(std::env::var_os("HOME").unwrap_or_default()).join(".local/bin/agent-usage-update");
        let records = load_records(&usage_dir);
        let applet = Self { core, popup: None, usage_dir, updater, records, selected: 0 };
        applet.refresh();
        (applet, Task::none())
    }

    fn on_close_requested(&self, id: Id) -> Option<Message> {
        Some(Message::PopupClosed(id))
    }

    fn view(&self) -> Element<'_, Message> {
        let mark = icon::from_svg_bytes(if self.alarming() { MARK_ALARM } else { MARK });
        let button = self.core.applet.icon_button_from_handle(mark).on_press(Message::TogglePopup);
        mouse_area(button).on_right_press(Message::Refresh).into()
    }

    fn view_window(&self, _id: Id) -> Element<'_, Message> {
        let content: Element<'_, Message> = if self.records.is_empty() {
            widget::text::body("No AI coding subscriptions found.\nAgents show up here once you've used them.").into()
        } else {
            let selected = self.selected.min(self.records.len() - 1);
            let mut column = widget::column::with_capacity(2).spacing(16);
            if self.records.len() > 1 {
                let mut chips = widget::row::with_capacity(self.records.len()).spacing(8);
                for (i, record) in self.records.iter().enumerate() {
                    let chip = if i == selected {
                        widget::button::suggested(record.name.as_str())
                    } else {
                        widget::button::standard(record.name.as_str())
                    };
                    chips = chips.push(chip.on_press(Message::Select(i)));
                }
                column = column.push(chips);
            }
            column.push(self.provider_view(&self.records[selected])).into()
        };
        let scroll = widget::scrollable(widget::container(content).padding([12, 16]).width(Length::Fixed(380.0)));
        self.core.applet.popup_container(scroll).into()
    }

    fn subscription(&self) -> Subscription<Message> {
        Subscription::batch([
            time::every(POLL).map(|_| Message::Reload),
            time::every(REFRESH).map(|_| Message::Refresh),
        ])
    }

    fn update(&mut self, message: Message) -> Task<cosmic::Action<Message>> {
        match message {
            Message::TogglePopup => {
                return match self.popup.take() {
                    Some(id) => destroy_popup(id),
                    None => {
                        self.records = load_records(&self.usage_dir);
                        let id = Id::unique();
                        self.popup = Some(id);
                        let mut settings = self.core.applet.get_popup_settings(
                            self.core.main_window_id().unwrap(),
                            id,
                            None,
                            None,
                            None,
                        );
                        settings.positioner.size_limits = Limits::NONE.min_width(300.0).max_width(420.0).min_height(80.0).max_height(720.0);
                        get_popup(settings)
                    }
                };
            }
            Message::PopupClosed(id) => {
                if self.popup == Some(id) {
                    self.popup = None;
                }
            }
            Message::Reload => self.records = load_records(&self.usage_dir),
            Message::Refresh => self.refresh(),
            Message::Select(i) => self.selected = i,
        }
        Task::none()
    }

    fn style(&self) -> Option<cosmic::iced::theme::Style> {
        Some(cosmic::applet::style())
    }
}
