//! Window control for shortcuts, over cosmic-comp's toplevel protocols. What Hyprland's
//! special workspaces and omarchy-launch-or-focus did:
//!   pneuma-wm list
//!   pneuma-wm activate <app-id>                 exit 1 when no such window
//!   pneuma-wm toggle <app-id> -- <command...>   minimize if focused, show if not, spawn if absent

use std::process::{Command, Stdio};

use cctk::{
    cosmic_protocols::toplevel_info::v1::client::zcosmic_toplevel_handle_v1::State,
    sctk::{
        self,
        registry::{ProvidesRegistryState, RegistryState},
        seat::{SeatHandler, SeatState},
    },
    toplevel_info::{ToplevelInfo, ToplevelInfoHandler, ToplevelInfoState},
    toplevel_management::{ToplevelManagerHandler, ToplevelManagerState},
    wayland_client::{Connection, QueueHandle, globals::registry_queue_init, protocol::wl_seat},
};

struct App {
    registry_state: RegistryState,
    seat_state: SeatState,
    toplevel_info_state: ToplevelInfoState,
    toplevel_manager_state: ToplevelManagerState,
}

impl ProvidesRegistryState for App {
    fn registry(&mut self) -> &mut RegistryState {
        &mut self.registry_state
    }
    sctk::registry_handlers![SeatState,];
}

impl SeatHandler for App {
    fn seat_state(&mut self) -> &mut SeatState {
        &mut self.seat_state
    }
    fn new_seat(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_seat::WlSeat) {}
    fn new_capability(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_seat::WlSeat, _: sctk::seat::Capability) {}
    fn remove_capability(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_seat::WlSeat, _: sctk::seat::Capability) {}
    fn remove_seat(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_seat::WlSeat) {}
}

impl ToplevelInfoHandler for App {
    fn toplevel_info_state(&mut self) -> &mut ToplevelInfoState {
        &mut self.toplevel_info_state
    }
    fn new_toplevel(&mut self, _: &Connection, _: &QueueHandle<Self>, _: &cctk::wayland_protocols::ext::foreign_toplevel_list::v1::client::ext_foreign_toplevel_handle_v1::ExtForeignToplevelHandleV1) {}
    fn update_toplevel(&mut self, _: &Connection, _: &QueueHandle<Self>, _: &cctk::wayland_protocols::ext::foreign_toplevel_list::v1::client::ext_foreign_toplevel_handle_v1::ExtForeignToplevelHandleV1) {}
    fn toplevel_closed(&mut self, _: &Connection, _: &QueueHandle<Self>, _: &cctk::wayland_protocols::ext::foreign_toplevel_list::v1::client::ext_foreign_toplevel_handle_v1::ExtForeignToplevelHandleV1) {}
}

impl ToplevelManagerHandler for App {
    fn toplevel_manager_state(&mut self) -> &mut ToplevelManagerState {
        &mut self.toplevel_manager_state
    }
    fn capabilities(&mut self, _: &Connection, _: &QueueHandle<Self>, _: Vec<cctk::wayland_client::WEnum<cctk::cosmic_protocols::toplevel_management::v1::client::zcosmic_toplevel_manager_v1::ZcosmicToplelevelManagementCapabilitiesV1>>) {}
}

sctk::delegate_registry!(App);
sctk::delegate_seat!(App);
cctk::delegate_toplevel_info!(App);
cctk::delegate_toplevel_manager!(App);

fn usage() -> ! {
    eprintln!("usage: pneuma-wm list | activate <app-id> | toggle <app-id> -- <command...>");
    std::process::exit(2)
}

fn spawn(command: &[String]) {
    let Some((program, args)) = command.split_first() else { usage() };
    let result = Command::new(program)
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn();
    if let Err(error) = result {
        eprintln!("pneuma-wm: cannot start {program}: {error}");
        std::process::exit(1);
    }
}

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let (verb, app_id, command) = match args.as_slice() {
        [verb] if verb == "list" => (verb.as_str(), "", &args[1..]),
        [verb, app_id] if verb == "activate" => (verb.as_str(), app_id.as_str(), &args[2..]),
        [verb, app_id, dashes, rest @ ..] if verb == "toggle" && dashes == "--" && !rest.is_empty() => {
            (verb.as_str(), app_id.as_str(), &args[3..])
        }
        _ => usage(),
    };

    let conn = Connection::connect_to_env().expect("no Wayland display");
    let (globals, mut queue) = registry_queue_init(&conn).expect("registry");
    let qh = queue.handle();
    let registry_state = RegistryState::new(&globals);
    let mut app = App {
        seat_state: SeatState::new(&globals, &qh),
        toplevel_info_state: ToplevelInfoState::new(&registry_state, &qh),
        toplevel_manager_state: ToplevelManagerState::new(&registry_state, &qh),
        registry_state,
    };
    // The toplevel list and each handle's state arrive over the first few roundtrips.
    for i in 0..3 {
        queue.roundtrip(&mut app).expect("roundtrip");
        eprintln!("DEBUG roundtrip {i}: {} toplevels, cosmic info bound: {}", app.toplevel_info_state.toplevels().count(), app.toplevel_info_state.cosmic_toplevel_info.is_some());
    }

    let windows: Vec<&ToplevelInfo> = app.toplevel_info_state.toplevels().collect();
    if verb == "list" {
        for w in &windows {
            let mut states: Vec<String> = w.state.iter().map(|s| format!("{s:?}").to_lowercase()).collect();
            states.sort();
            println!("{}\t{}\t{}", w.app_id, states.join(","), w.title);
        }
        return;
    }

    let Some(seat) = app.seat_state.seats().next() else {
        eprintln!("pneuma-wm: no seat");
        std::process::exit(1);
    };
    let manager = &app.toplevel_manager_state.manager;
    let target = windows
        .iter()
        .filter(|w| w.app_id == app_id)
        .max_by_key(|w| w.state.contains(&State::Activated));
    match (verb, target.and_then(|w| w.cosmic_toplevel.clone().map(|h| (h, w.state.clone())))) {
        ("activate", Some((handle, _))) => manager.activate(&handle, &seat),
        ("activate", None) => std::process::exit(1),
        ("toggle", Some((handle, state))) => {
            if state.contains(&State::Activated) {
                manager.set_minimized(&handle);
            } else {
                if state.contains(&State::Minimized) {
                    manager.unset_minimized(&handle);
                }
                manager.activate(&handle, &seat);
            }
        }
        ("toggle", None) => spawn(command),
        _ => usage(),
    }
    queue.roundtrip(&mut app).expect("roundtrip");
}
