//! Clipboard history picker (the omarchy.clipboard overlay): a session daemon whose `Toggle` on
//! dev.pneuma.Clipboard (Super+Ctrl+V, the panel button) shows a searchable list of what was
//! copied under the panel; picking an entry puts it back on the clipboard. Text and images are
//! captured by `pneuma-clipboard-watch`, which runs this binary with `--capture <mime>` from
//! `wl-paste --watch`.

use std::sync::LazyLock;
use std::time::Duration;

use cosmic::iced::futures::{SinkExt, channel::mpsc};
use cosmic::iced::platform_specific::shell::commands::layer_surface::{
    Anchor, KeyboardInteractivity, Layer, destroy_layer_surface, get_layer_surface,
};
use cosmic::iced::runtime::platform_specific::wayland::layer_surface::{IcedMargin, IcedOutput, SctkLayerSurfaceSettings};
use cosmic::iced::{self, Length, Subscription, keyboard, time, window::Id};
use cosmic::prelude::*;
use cosmic::widget::{self, button, icon, text_input};
use pneuma_clipboard::history::{self, Entry};

const APP_ID: &str = "dev.pneuma.Clipboard";
const ROWS: usize = 50;
static INPUT_ID: LazyLock<widget::Id> = LazyLock::new(|| widget::Id::new("filter"));

fn main() -> cosmic::iced::Result {
    let args: Vec<String> = std::env::args().collect();
    if let [_, flag, mime] = args.as_slice() {
        if flag == "--capture" {
            if let Err(err) = history::capture(mime) {
                eprintln!("pneuma clipboard capture: {err}");
            }
            return Ok(());
        }
    }
    // One instance is the systemd unit's job, so the plain runner is enough.
    cosmic::app::run::<Picker>(cosmic::app::Settings::default().no_main_window(true).exit_on_close(false), ())
}

struct Picker {
    core: cosmic::Core,
    surface: Option<Id>,
    entries: Vec<Entry>,
    filter: String,
    cursor: usize,
    /// Shift+Delete once arms the wipe; a second press within the same picker performs it.
    clear_armed: bool,
}

#[derive(Debug, Clone)]
enum Message {
    TogglePopup,
    Focused(Id),
    Unfocused(Id),
    Reload,
    Filter(String),
    Move(isize),
    PickCursor,
    Pick(usize),
    Delete { all: bool },
}

/// `Toggle` on dev.pneuma.Clipboard, for the shortcut.
struct Bus(mpsc::Sender<()>);

#[zbus::interface(name = "dev.pneuma.Clipboard")]
impl Bus {
    async fn toggle(&self) {
        let _ = self.0.clone().send(()).await;
    }
}

fn bus() -> Subscription<()> {
    Subscription::run(|| {
        iced::stream::channel(4, |output| async move {
            let built = zbus::connection::Builder::session()
                .and_then(|b| b.name("dev.pneuma.Clipboard"))
                .and_then(|b| b.serve_at("/dev/pneuma/Clipboard", Bus(output)));
            let _connection = match built {
                Ok(builder) => builder.build().await.ok(),
                Err(_) => None,
            };
            iced::futures::future::pending::<()>().await
        })
    })
}

impl Picker {
    /// History indexes of the entries the picker shows, filtered and capped.
    fn rows(&self) -> Vec<usize> {
        let needle = self.filter.trim().to_lowercase();
        self.entries.iter().enumerate().filter(|(_, e)| e.matches(&needle)).map(|(i, _)| i).take(ROWS).collect()
    }

    fn close(&mut self) -> Task<cosmic::Action<Message>> {
        self.surface.take().map_or_else(Task::none, destroy_layer_surface)
    }

    fn open(&mut self) -> Task<cosmic::Action<Message>> {
        self.entries = history::load();
        self.filter.clear();
        self.cursor = 0;
        self.clear_armed = false;
        let id = Id::unique();
        self.surface = Some(id);
        let surface = get_layer_surface(SctkLayerSurfaceSettings {
            id,
            layer: Layer::Top,
            keyboard_interactivity: KeyboardInteractivity::Exclusive,
            anchor: Anchor::TOP,
            output: IcedOutput::Active,
            namespace: "pneuma-clipboard".into(),
            margin: IcedMargin { top: 8, ..Default::default() },
            size: Some((Some(440), Some(520))),
            exclusive_zone: 0,
            ..Default::default()
        });
        surface
    }

    fn row<'a>(&self, index: usize, entry: &'a Entry, selected: bool) -> Element<'a, Message> {
        let mut row = widget::row::with_capacity(2).spacing(10).align_y(iced::Alignment::Center);
        row = match entry.thumbnail() {
            Some(path) => row.push(widget::image(widget::image::Handle::from_path(path)).height(40).content_fit(iced::ContentFit::Contain)),
            None => row.push(icon::from_name("edit-paste-symbolic").size(16)),
        };
        row = row.push(widget::text::body(entry.preview()).wrapping(iced::widget::text::Wrapping::None));
        button::custom(row)
            .width(Length::Fill)
            .padding([6, 8])
            .class(cosmic::theme::Button::MenuItem)
            .selected(selected)
            .on_press(Message::Pick(index))
            .into()
    }
}

impl cosmic::Application for Picker {
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
        let picker = Self { core, surface: None, entries: Vec::new(), filter: String::new(), cursor: 0, clear_armed: false };
        (picker, Task::none())
    }

    fn view(&self) -> Element<'_, Message> {
        widget::text("").into()
    }

    fn view_window(&self, _id: Id) -> Element<'_, Message> {
        let rows = self.rows();
        let search = text_input::search_input("Search clipboard", &self.filter)
            .id(INPUT_ID.clone())
            .on_input(Message::Filter)
            .on_submit(|_| Message::PickCursor);
        let mut list = widget::column::with_capacity(rows.len()).spacing(2);
        for (position, index) in rows.iter().enumerate() {
            list = list.push(self.row(*index, &self.entries[*index], position == self.cursor));
        }
        let hint = if self.clear_armed {
            "Shift+Delete again clears everything"
        } else if self.entries.is_empty() {
            "Nothing copied yet"
        } else {
            "Enter copies · Delete removes · Shift+Delete clears"
        };
        let column = widget::column::with_capacity(3)
            .spacing(8)
            .padding(8)
            .push(search)
            .push(widget::scrollable(list).height(Length::Shrink))
            .push(widget::text::caption(hint));
        widget::container(column)
            .class(cosmic::theme::Container::Dialog(false))
            .into()
    }

    fn subscription(&self) -> Subscription<Message> {
        let mut subscriptions = vec![bus().map(|()| Message::TogglePopup)];
        if self.surface.is_some() {
            subscriptions.push(time::every(Duration::from_secs(1)).map(|_| Message::Reload));
            subscriptions.push(iced::event::listen_with(|event, _, id| match event {
                // The search box can only take focus once the surface exists and has the keyboard.
                iced::Event::Window(iced::window::Event::Focused) => Some(Message::Focused(id)),
                iced::Event::Window(iced::window::Event::Unfocused) => Some(Message::Unfocused(id)),
                iced::Event::Keyboard(keyboard::Event::KeyPressed { key: keyboard::Key::Named(key), modifiers, .. }) => {
                    use keyboard::key::Named;
                    match key {
                        Named::Escape => Some(Message::TogglePopup),
                        Named::ArrowUp => Some(Message::Move(-1)),
                        Named::ArrowDown => Some(Message::Move(1)),
                        Named::PageUp => Some(Message::Move(-6)),
                        Named::PageDown => Some(Message::Move(6)),
                        Named::Delete => Some(Message::Delete { all: modifiers.shift() }),
                        _ => None,
                    }
                }
                _ => None,
            }));
        }
        Subscription::batch(subscriptions)
    }

    fn update(&mut self, message: Message) -> Task<cosmic::Action<Message>> {
        match message {
            Message::TogglePopup => return if self.surface.is_some() { self.close() } else { self.open() },
            Message::Focused(id) => {
                if self.surface == Some(id) {
                    return text_input::focus(INPUT_ID.clone());
                }
            }
            Message::Unfocused(id) => {
                if self.surface == Some(id) {
                    return self.close();
                }
            }
            Message::Reload => {
                let entries = history::load();
                if entries != self.entries {
                    self.entries = entries;
                    self.cursor = 0;
                }
            }
            Message::Filter(filter) => {
                self.filter = filter;
                self.cursor = 0;
            }
            Message::Move(delta) => {
                let last = self.rows().len().saturating_sub(1);
                self.cursor = (self.cursor as isize + delta).clamp(0, last as isize) as usize;
            }
            Message::PickCursor => {
                if let Some(index) = self.rows().get(self.cursor) {
                    return self.update(Message::Pick(*index));
                }
            }
            Message::Pick(index) => {
                if let Some(entry) = self.entries.get(index).cloned() {
                    entry.copy();
                    let _ = history::update(|entries| {
                        entries.retain(|e| *e != entry);
                        entries.insert(0, entry);
                    });
                }
                return self.close();
            }
            Message::Delete { all: true } => {
                if self.clear_armed {
                    let _ = history::update(Vec::clear);
                    self.entries.clear();
                    self.clear_armed = false;
                } else {
                    self.clear_armed = true;
                }
            }
            Message::Delete { all: false } => {
                if let Some(index) = self.rows().get(self.cursor).copied() {
                    let entry = self.entries.remove(index);
                    let _ = history::update(|entries| entries.retain(|e| *e != entry));
                    self.cursor = self.cursor.min(self.rows().len().saturating_sub(1));
                }
            }
        }
        Task::none()
    }

    fn style(&self) -> Option<cosmic::iced::theme::Style> {
        Some(cosmic::applet::style())
    }
}
