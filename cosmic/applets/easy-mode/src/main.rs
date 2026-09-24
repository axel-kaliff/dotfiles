//! Panel button for easy mode (floating windows, a dock, click-to-focus). The mode itself is
//! owned by cosmic/bin/pneuma-easy-mode; this shows its flag file and runs its toggle.

use std::path::PathBuf;
use std::process::Command;
use std::time::Duration;

use cosmic::iced::{Subscription, time};
use cosmic::prelude::*;

const APP_ID: &str = "dev.pneuma.EasyMode";
const POLL: Duration = Duration::from_secs(2);

fn main() -> cosmic::iced::Result {
    cosmic::applet::run::<Applet>(())
}

struct Applet {
    core: cosmic::Core,
    flag: PathBuf,
    script: PathBuf,
    on: bool,
}

#[derive(Debug, Clone)]
enum Message {
    Toggle,
    Poll,
}

fn home_dir(var: &str, fallback: &str) -> PathBuf {
    std::env::var_os(var).map_or_else(
        || {
            let home = std::env::var_os("HOME").unwrap_or_default();
            PathBuf::from(home).join(fallback)
        },
        PathBuf::from,
    )
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
        let flag = home_dir("XDG_STATE_HOME", ".local/state").join("pneuma/easy-mode");
        let script = PathBuf::from(std::env::var_os("HOME").unwrap_or_default())
            .join(".local/bin/pneuma-easy-mode");
        let on = flag.exists();
        (Self { core, flag, script, on }, Task::none())
    }

    fn view(&self) -> Element<'_, Message> {
        // Mouse when the desktop is mouse-driven, keyboard when it tiles.
        let icon = if self.on { "input-mouse-symbolic" } else { "input-keyboard-symbolic" };
        self.core.applet.icon_button(icon).on_press(Message::Toggle).into()
    }

    fn subscription(&self) -> Subscription<Message> {
        time::every(POLL).map(|_| Message::Poll)
    }

    fn update(&mut self, message: Message) -> Task<cosmic::Action<Message>> {
        match message {
            Message::Poll => self.on = self.flag.exists(),
            Message::Toggle => {
                self.on = !self.on;
                if let Ok(mut child) = Command::new(&self.script).arg("toggle").spawn() {
                    // Reap the script when it exits; it runs for well under a second.
                    std::thread::spawn(move || child.wait());
                }
            }
        }
        Task::none()
    }

    fn style(&self) -> Option<cosmic::iced::theme::Style> {
        Some(cosmic::applet::style())
    }
}
