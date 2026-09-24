//! Workspaces on the panel's output with the apps on each, from cosmic-comp's workspace and
//! toplevel-info protocols on a thread of their own. The connection handling is adapted from
//! cosmic-applet-workspaces (System76, GPL-3.0-only).

use std::hash::Hash;
use std::thread;

use cosmic::cctk::{
    self,
    sctk::{
        self,
        output::{OutputHandler, OutputState},
        registry::{ProvidesRegistryState, RegistryState},
    },
    toplevel_info::{ToplevelInfoHandler, ToplevelInfoState},
    wayland_client::{Connection, QueueHandle, globals::registry_queue_init, protocol::wl_output::WlOutput},
    wayland_protocols::ext::{
        foreign_toplevel_list::v1::client::ext_foreign_toplevel_handle_v1::ExtForeignToplevelHandleV1,
        workspace::v1::client::{
            ext_workspace_handle_v1::{ExtWorkspaceHandleV1, State},
            ext_workspace_manager_v1::ExtWorkspaceManagerV1,
        },
    },
    workspace::{WorkspaceHandler, WorkspaceState},
};
use cosmic::iced;
use futures::{SinkExt, channel::mpsc, executor::block_on};

/// Enough icons to say what a workspace holds; a busy one stays a pill rather than a dock.
const MAX_ICONS: usize = 4;

#[derive(Debug, Clone, PartialEq)]
pub struct Workspace {
    pub handle: ExtWorkspaceHandleV1,
    pub name: String,
    pub active: bool,
    pub urgent: bool,
    /// Distinct app ids in window order.
    pub app_ids: Vec<String>,
}

#[derive(Debug, Clone)]
pub enum Event {
    Manager(ExtWorkspaceManagerV1),
    Workspaces(Vec<Workspace>),
}

pub fn subscription(connection: Connection) -> iced::Subscription<Event> {
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
    output_state: OutputState,
    workspace_state: WorkspaceState,
    toplevel_info_state: ToplevelInfoState,
    /// The output the panel told us it sits on (COSMIC_PANEL_OUTPUT).
    panel_output: String,
    sender: mpsc::Sender<Event>,
    manager_sent: bool,
    last: Vec<Workspace>,
}

impl App {
    fn panel_output(&self) -> Option<WlOutput> {
        self.output_state
            .outputs()
            .find(|output| self.output_state.info(output).and_then(|info| info.name).as_deref() == Some(&self.panel_output))
    }

    fn list(&self) -> Vec<Workspace> {
        let output = self.panel_output();
        let mut groups: Vec<_> = self.workspace_state.workspace_groups().collect();
        let on_output: Vec<_> =
            groups.iter().copied().filter(|group| output.as_ref().is_some_and(|o| group.outputs.contains(o))).collect();
        if !on_output.is_empty() {
            groups = on_output;
        }
        let mut list: Vec<(Vec<u32>, Workspace)> = groups
            .iter()
            .flat_map(|group| group.workspaces.iter())
            .filter_map(|handle| self.workspace_state.workspace_info(handle))
            .filter(|info| !info.state.contains(State::Hidden))
            .map(|info| {
                let mut app_ids = Vec::new();
                for toplevel in self.toplevel_info_state.toplevels() {
                    if app_ids.len() == MAX_ICONS {
                        break;
                    }
                    if toplevel.workspace.contains(&info.handle)
                        && !toplevel.app_id.is_empty()
                        && !app_ids.contains(&toplevel.app_id)
                    {
                        app_ids.push(toplevel.app_id.clone());
                    }
                }
                let workspace = Workspace {
                    handle: info.handle.clone(),
                    name: info.name.clone(),
                    active: info.state.contains(State::Active),
                    urgent: info.state.contains(State::Urgent),
                    app_ids,
                };
                (info.coordinates.clone(), workspace)
            })
            .collect();
        list.sort_by(|a, b| a.0.cmp(&b.0));
        list.into_iter().map(|(_, workspace)| workspace).collect()
    }

    fn publish(&mut self) {
        if !self.manager_sent {
            if let Ok(manager) = self.workspace_state.workspace_manager().get() {
                self.manager_sent = true;
                let _ = block_on(self.sender.send(Event::Manager(manager.clone())));
            }
        }
        let list = self.list();
        if list != self.last {
            self.last.clone_from(&list);
            let _ = block_on(self.sender.send(Event::Workspaces(list)));
        }
    }
}

impl ProvidesRegistryState for App {
    fn registry(&mut self) -> &mut RegistryState {
        &mut self.registry_state
    }
    sctk::registry_handlers![OutputState,];
}

impl OutputHandler for App {
    fn output_state(&mut self) -> &mut OutputState {
        &mut self.output_state
    }
    fn new_output(&mut self, _: &Connection, _: &QueueHandle<Self>, _: WlOutput) {
        self.publish();
    }
    fn update_output(&mut self, _: &Connection, _: &QueueHandle<Self>, _: WlOutput) {}
    fn output_destroyed(&mut self, _: &Connection, _: &QueueHandle<Self>, _: WlOutput) {}
}

impl WorkspaceHandler for App {
    fn workspace_state(&mut self) -> &mut WorkspaceState {
        &mut self.workspace_state
    }
    fn done(&mut self) {
        self.publish();
    }
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
sctk::delegate_output!(App);
cctk::delegate_workspace!(App);
cctk::delegate_toplevel_info!(App);

fn run(conn: Connection, sender: mpsc::Sender<Event>) {
    let Ok((globals, mut queue)) = registry_queue_init(&conn) else { return };
    let qh = queue.handle();
    let registry_state = RegistryState::new(&globals);
    // Outputs must be bound before the workspace state so groups can name them.
    let output_state = OutputState::new(&globals, &qh);
    let workspace_state = WorkspaceState::new(&registry_state, &qh);
    let Some(toplevel_info_state) = ToplevelInfoState::try_new(&registry_state, &qh) else { return };
    let mut app = App {
        registry_state,
        output_state,
        workspace_state,
        toplevel_info_state,
        panel_output: std::env::var("COSMIC_PANEL_OUTPUT").unwrap_or_default(),
        sender,
        manager_sent: false,
        last: Vec::new(),
    };
    while queue.blocking_dispatch(&mut app).is_ok() {}
}
