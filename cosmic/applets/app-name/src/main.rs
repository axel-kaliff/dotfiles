//! The focused application's name in bold (the pneuma.app-name bar widget): the macOS menu bar's
//! signature, shown in the easy-mode bar. The name comes from the desktop entry the launcher
//! would resolve; the bare app id is the fallback, since a terse id beats an empty slot.

mod wayland;

use std::os::fd::{FromRawFd, RawFd};
use std::os::unix::net::UnixStream;
use std::sync::LazyLock;

use cosmic::cctk::wayland_client::Connection;
use cosmic::desktop::{DesktopEntryCache, DesktopLookupContext, DesktopResolveOptions, fde, resolve_desktop_entry};
use cosmic::iced::widget::text::Wrapping;
use cosmic::iced::{Alignment, Length, Subscription};
use cosmic::prelude::*;
use cosmic::widget::{self, autosize};

const APP_ID: &str = "dev.pneuma.AppName";
static AUTOSIZE_ID: LazyLock<widget::Id> = LazyLock::new(|| widget::Id::new("autosize-main"));

fn main() -> cosmic::iced::Result {
    // The panel hands compositor-talking applets a privileged socket (X-HostWaylandDisplay=true).
    let connection = std::env::var("X_PRIVILEGED_WAYLAND_SOCKET")
        .ok()
        .and_then(|fd| fd.parse::<RawFd>().ok())
        .map(|fd| unsafe { UnixStream::from_raw_fd(fd) })
        .and_then(|socket| Connection::from_socket(socket).ok())
        .or_else(|| Connection::connect_to_env().ok())
        .expect("a Wayland display");
    cosmic::applet::run::<Applet>(connection)
}

struct Applet {
    core: cosmic::Core,
    connection: Connection,
    entries: DesktopEntryCache,
    name: String,
}

#[derive(Debug, Clone)]
enum Message {
    Focused(Option<String>),
}

impl cosmic::Application for Applet {
    type Executor = cosmic::executor::Default;
    type Flags = Connection;
    type Message = Message;
    const APP_ID: &'static str = APP_ID;

    fn core(&self) -> &cosmic::Core {
        &self.core
    }

    fn core_mut(&mut self) -> &mut cosmic::Core {
        &mut self.core
    }

    fn init(core: cosmic::Core, connection: Connection) -> (Self, Task<cosmic::Action<Message>>) {
        let mut entries = DesktopEntryCache::new(fde::get_languages_from_env());
        entries.ensure_loaded();
        (Self { core, connection, entries, name: String::new() }, Task::none())
    }

    fn view(&self) -> Element<'_, Message> {
        if self.name.is_empty() {
            return widget::Space::new().into();
        }
        // No wrapping: a wrapped measurement would keep the surface as narrow as it started.
        let text = self.core.applet.text(self.name.as_str()).font(cosmic::font::bold()).wrapping(Wrapping::None);
        let padding = self.core.applet.suggested_padding(true).1;
        let height = self.core.applet.suggested_window_size().1.get() as f32;
        let content = widget::container(text).padding([0, padding]).height(Length::Fixed(height)).align_y(Alignment::Center);
        autosize::autosize(content, AUTOSIZE_ID.clone()).into()
    }

    fn subscription(&self) -> Subscription<Message> {
        wayland::subscription(self.connection.clone()).map(Message::Focused)
    }

    fn update(&mut self, message: Message) -> Task<cosmic::Action<Message>> {
        let Message::Focused(app_id) = message;
        self.name = app_id
            .filter(|id| !id.is_empty())
            .map(|id| {
                let entry = resolve_desktop_entry(
                    &mut self.entries,
                    &DesktopLookupContext::new(id.as_str()),
                    &DesktopResolveOptions::default(),
                );
                entry.name(self.entries.locales()).map_or(id, |name| name.into_owned())
            })
            .unwrap_or_default();
        Task::none()
    }

    fn style(&self) -> Option<cosmic::iced::theme::Style> {
        Some(cosmic::applet::style())
    }
}
