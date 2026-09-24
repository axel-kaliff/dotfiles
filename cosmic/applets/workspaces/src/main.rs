//! Workspace pills (the akaliff.workspaces bar widget): every workspace on the panel's output as
//! its number plus up to four icons of the apps on it. Empty workspaces are dimmed and the active
//! one sits in a glass pill; a click switches to it.

mod wayland;

use std::collections::HashMap;
use std::os::fd::{FromRawFd, RawFd};
use std::os::unix::net::UnixStream;
use std::sync::LazyLock;

use cosmic::cctk::wayland_client::Connection;
use cosmic::cctk::wayland_protocols::ext::workspace::v1::client::{
    ext_workspace_handle_v1::ExtWorkspaceHandleV1, ext_workspace_manager_v1::ExtWorkspaceManagerV1,
};
use cosmic::desktop::{
    DesktopEntryCache, DesktopLookupContext, DesktopResolveOptions, IconSourceExt, fde, resolve_desktop_entry,
};
use cosmic::iced::{Alignment, Background, Color, Length, Subscription};
use cosmic::prelude::*;
use cosmic::widget::{self, autosize, button, icon};

const APP_ID: &str = "dev.pneuma.Workspaces";
const ICON_SIZE: u16 = 14;
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
    manager: Option<ExtWorkspaceManagerV1>,
    workspaces: Vec<wayland::Workspace>,
    entries: DesktopEntryCache,
    icons: HashMap<String, icon::Handle>,
}

#[derive(Debug, Clone)]
enum Message {
    Wayland(wayland::Event),
    Activate(ExtWorkspaceHandleV1),
}

impl Applet {
    /// Resolves an app id through the desktop entries, the way the launcher does.
    fn cache_icon(&mut self, app_id: &str) {
        if self.icons.contains_key(app_id) {
            return;
        }
        let entry =
            resolve_desktop_entry(&mut self.entries, &DesktopLookupContext::new(app_id), &DesktopResolveOptions::default());
        let handle = fde::IconSource::from_unknown(entry.icon().unwrap_or_default()).as_cosmic_icon();
        self.icons.insert(app_id.to_owned(), handle);
    }
}

/// Glass pill for the active workspace, a dim digit for an empty one, a lift on hover.
fn pill(active: bool, urgent: bool, occupied: bool) -> cosmic::theme::Button {
    let style = move |theme: &cosmic::Theme, hovered: bool| {
        let cosmic = theme.cosmic();
        let on: Color = theme.current_container().component.on.into();
        let fill = |alpha| Some(Background::Color(Color { a: alpha, ..on }));
        let mut text = on;
        if urgent {
            text = cosmic.destructive_button.base.into();
        } else if !(active || occupied) {
            text.a = 0.5;
        }
        button::Style {
            background: if active {
                fill(0.18)
            } else if hovered {
                fill(0.10)
            } else {
                None
            },
            border_radius: cosmic.radius_xl().into(),
            border_width: if active { 1.0 } else { 0.0 },
            border_color: Color { a: 0.35, ..on },
            text_color: Some(text),
            icon_color: Some(text),
            ..button::Style::default()
        }
    };
    cosmic::theme::Button::Custom {
        active: Box::new(move |_, theme| style(theme, false)),
        disabled: Box::new(move |theme| style(theme, false)),
        hovered: Box::new(move |_, theme| style(theme, true)),
        pressed: Box::new(move |_, theme| style(theme, true)),
    }
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
        let applet = Self { core, connection, manager: None, workspaces: Vec::new(), entries, icons: HashMap::new() };
        (applet, Task::none())
    }

    fn view(&self) -> Element<'_, Message> {
        let padding = self.core.applet.suggested_padding(true).1;
        let height = self.core.applet.suggested_window_size().1.get() as f32;
        let pills = self.workspaces.iter().map(|workspace| {
            let mut content = widget::row::with_capacity(1 + workspace.app_ids.len())
                .spacing(4)
                .align_y(Alignment::Center)
                .push(self.core.applet.text(workspace.name.as_str()).font(cosmic::font::bold()));
            for handle in workspace.app_ids.iter().filter_map(|id| self.icons.get(id)) {
                content = content.push(icon::icon(handle.clone()).size(ICON_SIZE));
            }
            button::custom(content)
                .padding([0, padding])
                .height(Length::Fixed(height))
                .on_press(Message::Activate(workspace.handle.clone()))
                .class(pill(workspace.active, workspace.urgent, !workspace.app_ids.is_empty()))
                .into()
        });
        let row = widget::row::with_children(pills).spacing(2).align_y(Alignment::Center);
        autosize::autosize(row, AUTOSIZE_ID.clone()).into()
    }

    fn subscription(&self) -> Subscription<Message> {
        wayland::subscription(self.connection.clone()).map(Message::Wayland)
    }

    fn update(&mut self, message: Message) -> Task<cosmic::Action<Message>> {
        match message {
            Message::Wayland(wayland::Event::Manager(manager)) => self.manager = Some(manager),
            Message::Wayland(wayland::Event::Workspaces(list)) => {
                for app_id in list.iter().flat_map(|workspace| workspace.app_ids.iter()) {
                    self.cache_icon(app_id);
                }
                self.workspaces = list;
            }
            Message::Activate(handle) => {
                if let Some(manager) = &self.manager {
                    handle.activate();
                    manager.commit();
                    let _ = self.connection.flush();
                }
            }
        }
        Task::none()
    }

    fn style(&self) -> Option<cosmic::iced::theme::Style> {
        Some(cosmic::applet::style())
    }
}
