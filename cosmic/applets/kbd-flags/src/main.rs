//! Panel flag for the active keyboard layout (the pneuma.keyboard-layout bar widget):
//! a GB flag for us, SE for se, the code for anything else; a click moves to the next
//! layout in the CosmicComp xkb list. Flags are SVGs because the panel's text renderer
//! draws nothing for Fedora's COLRv1 emoji font.

mod wayland;

use std::os::unix::{
    io::{FromRawFd, RawFd},
    net::UnixStream,
};

use cctk::{
    cosmic_protocols::keyboard_layout::v1::client::zcosmic_keyboard_layout_v1::ZcosmicKeyboardLayoutV1,
    wayland_client::{Connection, Proxy, backend::Backend},
};
use cosmic::cosmic_config::{self, CosmicConfigEntry, cosmic_config_derive::CosmicConfigEntry};
use cosmic::iced::{
    self, Subscription,
    event::wayland::{Event as WaylandEvent, OutputEvent},
};
use cosmic::prelude::*;
use cosmic::widget::{self, autosize, icon};
use serde::{Deserialize, Serialize};
use std::sync::LazyLock;

const APP_ID: &str = "dev.pneuma.KeyboardFlags";
// Text applets size their panel window through autosize; without it the window stays at zero width.
static AUTOSIZE_ID: LazyLock<widget::Id> = LazyLock::new(|| widget::Id::new("pneuma-kbd-flags"));

/// The shape of com.system76.CosmicComp/v1/xkb_config (cosmic-comp-config's XkbConfig), declared
/// here so the applet shares one cosmic-config version with libcosmic.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
struct XkbConfig {
    rules: String,
    model: String,
    layout: String,
    variant: String,
    options: Option<String>,
    repeat_delay: u32,
    repeat_rate: u32,
}

/// The one CosmicComp key this applet reads.
#[derive(Debug, Clone, Default, PartialEq, Eq, CosmicConfigEntry)]
#[version = 1]
struct CompConfig {
    xkb_config: XkbConfig,
}

fn main() -> cosmic::iced::Result {
    // The panel hands compositor-talking applets a privileged socket (X-HostWaylandDisplay=true).
    let connection = std::env::var("X_PRIVILEGED_WAYLAND_SOCKET")
        .ok()
        .and_then(|fd| fd.parse::<RawFd>().ok())
        .map(|fd| unsafe { UnixStream::from_raw_fd(fd) })
        .and_then(|socket| Connection::from_socket(socket).ok());
    cosmic::applet::run::<Applet>(connection)
}

fn flag(layout: &str) -> Option<icon::Handle> {
    let bytes: &'static [u8] = match layout {
        "us" | "gb" => include_bytes!("../resources/gb.svg"),
        "se" => include_bytes!("../resources/se.svg"),
        _ => return None,
    };
    Some(icon::from_svg_bytes(bytes))
}

struct Applet {
    core: cosmic::Core,
    connection: Option<Connection>,
    keyboard_layout: Option<ZcosmicKeyboardLayoutV1>,
    layouts: Vec<String>,
    current: usize,
}

#[derive(Debug, Clone)]
enum Message {
    Next,
    CompConfig(Box<CompConfig>),
    WaylandConnection(Backend),
    Wayland(wayland::Event),
}

impl cosmic::Application for Applet {
    type Executor = cosmic::SingleThreadExecutor;
    type Flags = Option<Connection>;
    type Message = Message;
    const APP_ID: &'static str = APP_ID;

    fn core(&self) -> &cosmic::Core {
        &self.core
    }

    fn core_mut(&mut self) -> &mut cosmic::Core {
        &mut self.core
    }

    fn init(core: cosmic::Core, connection: Option<Connection>) -> (Self, Task<cosmic::Action<Message>>) {
        let applet = Self { core, connection, keyboard_layout: None, layouts: Vec::new(), current: 0 };
        (applet, Task::none())
    }

    fn view(&self) -> Element<'_, Message> {
        let layout = self.layouts.get(self.current).map_or("", String::as_str);
        match flag(layout) {
            Some(handle) => self.core.applet.icon_button_from_handle(handle).on_press(Message::Next).into(),
            None => {
                let text = self.core.applet.text(layout.to_uppercase());
                let button = self.core.applet.text_button(text, Message::Next);
                autosize::autosize(button, AUTOSIZE_ID.clone()).into()
            }
        }
    }

    fn update(&mut self, message: Message) -> Task<cosmic::Action<Message>> {
        match message {
            Message::Next => {
                if let Some(keyboard_layout) = &self.keyboard_layout
                    && !self.layouts.is_empty()
                {
                    let next = (self.current + 1) % self.layouts.len();
                    keyboard_layout.set_group(next as u32);
                    if let Some(backend) = keyboard_layout.backend().upgrade() {
                        let _ = backend.flush();
                    }
                }
            }
            Message::CompConfig(config) => {
                self.layouts = config
                    .xkb_config
                    .layout
                    .split_terminator(',')
                    .map(str::to_owned)
                    .collect();
            }
            Message::WaylandConnection(backend) => {
                if self.connection.is_none() {
                    self.connection = Some(Connection::from_backend(backend));
                }
            }
            Message::Wayland(wayland::Event::KeyboardLayout(keyboard_layout)) => {
                self.keyboard_layout = Some(keyboard_layout);
            }
            Message::Wayland(wayland::Event::Group(group)) => self.current = group,
        }
        Task::none()
    }

    fn subscription(&self) -> Subscription<Message> {
        let config = self
            .core
            .watch_config::<CompConfig>("com.system76.CosmicComp")
            .map(|update| Message::CompConfig(Box::new(update.config)));
        let wayland = match &self.connection {
            Some(connection) => wayland::subscription(connection.clone()).map(Message::Wayland),
            // Without the privileged socket, wait for the applet's own connection to surface.
            None => iced::event::listen_with(|event, _, _| match event {
                iced::Event::PlatformSpecific(iced::event::PlatformSpecific::Wayland(
                    WaylandEvent::Output(OutputEvent::Created(_), output),
                )) => output.backend().upgrade().map(Message::WaylandConnection),
                _ => None,
            }),
        };
        Subscription::batch([config, wayland])
    }

    fn style(&self) -> Option<cosmic::iced::theme::Style> {
        Some(cosmic::applet::style())
    }
}
