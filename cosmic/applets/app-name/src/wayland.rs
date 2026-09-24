//! The app id of the activated toplevel, from cosmic-comp's toplevel-info protocol on a thread of
//! its own; `None` while nothing has focus.

use std::hash::Hash;
use std::thread;

use cosmic::cctk::{
    self,
    cosmic_protocols::toplevel_info::v1::client::zcosmic_toplevel_handle_v1::State,
    sctk::{
        self,
        registry::{ProvidesRegistryState, RegistryState},
    },
    toplevel_info::{ToplevelInfoHandler, ToplevelInfoState},
    wayland_client::{Connection, QueueHandle, globals::registry_queue_init},
    wayland_protocols::ext::foreign_toplevel_list::v1::client::ext_foreign_toplevel_handle_v1::ExtForeignToplevelHandleV1,
};
use cosmic::iced;
use futures::{SinkExt, channel::mpsc, executor::block_on};

pub fn subscription(connection: Connection) -> iced::Subscription<Option<String>> {
    #[derive(Clone)]
    struct WaylandSubscription(Connection);
    impl Hash for WaylandSubscription {
        fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
            self.0.backend().display_id().hash(state);
        }
    }
    iced::Subscription::run_with(WaylandSubscription(connection), |WaylandSubscription(connection)| {
        let connection = connection.clone();
        iced::stream::channel(8, move |sender| async move {
            thread::spawn(move || run(connection, sender));
        })
    })
}

struct App {
    registry_state: RegistryState,
    toplevel_info_state: ToplevelInfoState,
    sender: mpsc::Sender<Option<String>>,
    last: Option<String>,
}

impl App {
    fn publish(&mut self) {
        let focused = self
            .toplevel_info_state
            .toplevels()
            .find(|info| info.state.contains(&State::Activated))
            .map(|info| info.app_id.clone());
        if focused != self.last {
            self.last.clone_from(&focused);
            let _ = block_on(self.sender.send(focused));
        }
    }
}

impl ProvidesRegistryState for App {
    fn registry(&mut self) -> &mut RegistryState {
        &mut self.registry_state
    }
    sctk::registry_handlers![];
}

impl ToplevelInfoHandler for App {
    fn toplevel_info_state(&mut self) -> &mut ToplevelInfoState {
        &mut self.toplevel_info_state
    }
    fn new_toplevel(&mut self, _: &Connection, _: &QueueHandle<Self>, _: &ExtForeignToplevelHandleV1) {
        self.publish();
    }
    fn update_toplevel(&mut self, _: &Connection, _: &QueueHandle<Self>, _: &ExtForeignToplevelHandleV1) {
        self.publish();
    }
    fn toplevel_closed(&mut self, _: &Connection, _: &QueueHandle<Self>, _: &ExtForeignToplevelHandleV1) {
        self.publish();
    }
}

sctk::delegate_registry!(App);
cctk::delegate_toplevel_info!(App);

fn run(conn: Connection, sender: mpsc::Sender<Option<String>>) {
    let Ok((globals, mut queue)) = registry_queue_init(&conn) else { return };
    let qh = queue.handle();
    let registry_state = RegistryState::new(&globals);
    let Some(toplevel_info_state) = ToplevelInfoState::try_new(&registry_state, &qh) else { return };
    let mut app = App { registry_state, toplevel_info_state, sender, last: None };
    while queue.blocking_dispatch(&mut app).is_ok() {}
}
