//! Window control for shortcuts, over cosmic-comp's toplevel protocols. What Hyprland's
//! special workspaces and omarchy-launch-or-focus did:
//!   pneuma-wm list
//!   pneuma-wm activate <app-id>                 exit 1 when no such window
//!   pneuma-wm toggle <app-id> -- <command...>   minimize if focused, show if not, spawn if absent
//!
//! The protocol state is kept here rather than through cosmic-client-toolkit: its
//! `ToplevelInfoState` only publishes a window after an ext `done` that follows the cosmic
//! state event, which a one-shot client never receives.

use std::collections::HashSet;
use std::process::{Command, Stdio};

use cctk::cosmic_protocols::toplevel_info::v1::client::{
    zcosmic_toplevel_handle_v1::{self, ZcosmicToplevelHandleV1},
    zcosmic_toplevel_info_v1::{self, ZcosmicToplevelInfoV1},
};
use cctk::cosmic_protocols::toplevel_management::v1::client::zcosmic_toplevel_manager_v1::{
    self, ZcosmicToplevelManagerV1,
};
use cctk::wayland_client::{
    Connection, Dispatch, QueueHandle, delegate_noop, event_created_child,
    globals::{GlobalListContents, registry_queue_init},
    protocol::{wl_registry, wl_seat::WlSeat},
};
use cctk::wayland_protocols::ext::foreign_toplevel_list::v1::client::{
    ext_foreign_toplevel_handle_v1::{self, ExtForeignToplevelHandleV1},
    ext_foreign_toplevel_list_v1::{self, ExtForeignToplevelListV1},
};

#[derive(Default)]
struct Window {
    app_id: String,
    title: String,
    state: HashSet<zcosmic_toplevel_handle_v1::State>,
    has_state: bool,
    cosmic: Option<ZcosmicToplevelHandleV1>,
}

#[derive(Default)]
struct App {
    windows: Vec<(ExtForeignToplevelHandleV1, Window)>,
    info: Option<ZcosmicToplevelInfoV1>,
}

impl App {
    fn window_mut(&mut self, handle: &ExtForeignToplevelHandleV1) -> &mut Window {
        let index = self.windows.iter().position(|(h, _)| h == handle).expect("unknown toplevel");
        &mut self.windows[index].1
    }
}

impl Dispatch<ExtForeignToplevelListV1, ()> for App {
    fn event(
        app: &mut Self,
        _: &ExtForeignToplevelListV1,
        event: ext_foreign_toplevel_list_v1::Event,
        _: &(),
        _: &Connection,
        qh: &QueueHandle<Self>,
    ) {
        if let ext_foreign_toplevel_list_v1::Event::Toplevel { toplevel } = event {
            let cosmic = app.info.as_ref().map(|info| info.get_cosmic_toplevel(&toplevel, qh, ()));
            app.windows.push((toplevel, Window { cosmic, ..Window::default() }));
        }
    }

    event_created_child!(App, ExtForeignToplevelListV1, [
        ext_foreign_toplevel_list_v1::EVT_TOPLEVEL_OPCODE => (ExtForeignToplevelHandleV1, ()),
    ]);
}

impl Dispatch<ExtForeignToplevelHandleV1, ()> for App {
    fn event(
        app: &mut Self,
        handle: &ExtForeignToplevelHandleV1,
        event: ext_foreign_toplevel_handle_v1::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        match event {
            ext_foreign_toplevel_handle_v1::Event::Title { title } => app.window_mut(handle).title = title,
            ext_foreign_toplevel_handle_v1::Event::AppId { app_id } => app.window_mut(handle).app_id = app_id,
            ext_foreign_toplevel_handle_v1::Event::Closed => app.windows.retain(|(h, _)| h != handle),
            _ => {}
        }
    }
}

impl Dispatch<ZcosmicToplevelHandleV1, ()> for App {
    fn event(
        app: &mut Self,
        handle: &ZcosmicToplevelHandleV1,
        event: zcosmic_toplevel_handle_v1::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        if let zcosmic_toplevel_handle_v1::Event::State { state } = event
            && let Some((_, window)) = app.windows.iter_mut().find(|(_, w)| w.cosmic.as_ref() == Some(handle))
        {
            window.has_state = true;
            window.state = state
                .chunks_exact(4)
                .filter_map(|bytes| u32::from_ne_bytes(bytes.try_into().ok()?).try_into().ok())
                .collect();
        }
    }
}

// Globals whose events carry nothing this tool needs.
impl Dispatch<ZcosmicToplevelInfoV1, ()> for App {
    fn event(_: &mut Self, _: &ZcosmicToplevelInfoV1, _: zcosmic_toplevel_info_v1::Event, _: &(), _: &Connection, _: &QueueHandle<Self>) {}

    // The legacy v1 `toplevel` event also creates a handle; the binding must know its type.
    event_created_child!(App, ZcosmicToplevelInfoV1, [
        zcosmic_toplevel_info_v1::EVT_TOPLEVEL_OPCODE => (ZcosmicToplevelHandleV1, ()),
    ]);
}
impl Dispatch<ZcosmicToplevelManagerV1, ()> for App {
    fn event(_: &mut Self, _: &ZcosmicToplevelManagerV1, _: zcosmic_toplevel_manager_v1::Event, _: &(), _: &Connection, _: &QueueHandle<Self>) {}
}
impl Dispatch<wl_registry::WlRegistry, GlobalListContents> for App {
    fn event(_: &mut Self, _: &wl_registry::WlRegistry, _: wl_registry::Event, _: &GlobalListContents, _: &Connection, _: &QueueHandle<Self>) {}
}
delegate_noop!(App: ignore WlSeat);

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
    let (globals, mut queue) = registry_queue_init::<App>(&conn).expect("registry");
    let qh = queue.handle();
    let mut app = App {
        info: globals.bind::<ZcosmicToplevelInfoV1, _, _>(&qh, 2..=3, ()).ok(),
        ..App::default()
    };
    let _list: ExtForeignToplevelListV1 = globals.bind(&qh, 1..=1, ()).expect("ext_foreign_toplevel_list_v1");
    let manager: ZcosmicToplevelManagerV1 = globals.bind(&qh, 1..=4, ()).expect("zcosmic_toplevel_manager_v1");
    let seat: WlSeat = globals.bind(&qh, 1..=1, ()).expect("wl_seat");
    // The list arrives on the first roundtrip; cosmic-comp sends each window's state a little
    // later, on its own schedule, so keep polling briefly until every window has reported one.
    queue.roundtrip(&mut app).expect("roundtrip");
    for _ in 0..20 {
        queue.roundtrip(&mut app).expect("roundtrip");
        if app.info.is_none() || app.windows.iter().all(|(_, w)| w.has_state) {
            break;
        }
        std::thread::sleep(std::time::Duration::from_millis(25));
    }

    if verb == "list" {
        for (_, w) in &app.windows {
            let mut states: Vec<String> = w.state.iter().map(|s| format!("{s:?}").to_lowercase()).collect();
            states.sort();
            println!("{}\t{}\t{}", w.app_id, states.join(","), w.title);
        }
        return;
    }

    let target = app
        .windows
        .iter()
        // Case-blind: one app can report `spotify` natively and `Spotify` under XWayland.
        .filter(|(_, w)| w.app_id.eq_ignore_ascii_case(app_id))
        .max_by_key(|(_, w)| w.state.contains(&zcosmic_toplevel_handle_v1::State::Activated))
        .and_then(|(_, w)| w.cosmic.clone().map(|handle| (handle, w.state.clone())));
    match (verb, target) {
        ("activate", Some((handle, _))) => manager.activate(&handle, &seat),
        ("activate", None) => std::process::exit(1),
        ("toggle", Some((handle, state))) => {
            if state.contains(&zcosmic_toplevel_handle_v1::State::Activated) {
                manager.set_minimized(&handle);
            } else {
                if state.contains(&zcosmic_toplevel_handle_v1::State::Minimized) {
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
