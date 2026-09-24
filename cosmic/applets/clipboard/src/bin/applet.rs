//! The panel button for the clipboard history (the pneuma.clipboard bar widget): it toggles the
//! picker that `pneuma-clipboard-picker` draws, the same call Super+Ctrl+V makes.

use std::path::PathBuf;
use std::process::Command;

use cosmic::prelude::*;

const APP_ID: &str = "dev.pneuma.Clipboard";

fn main() -> cosmic::iced::Result {
    cosmic::applet::run::<Applet>(())
}

struct Applet {
    core: cosmic::Core,
    toggle: PathBuf,
}

#[derive(Debug, Clone)]
enum Message {
    Toggle,
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
        let home = PathBuf::from(std::env::var_os("HOME").unwrap_or_default());
        (Self { core, toggle: home.join(".local/bin/pneuma-clipboard") }, Task::none())
    }

    fn view(&self) -> Element<'_, Message> {
        self.core.applet.icon_button("edit-paste-symbolic").on_press(Message::Toggle).into()
    }

    fn update(&mut self, Message::Toggle: Message) -> Task<cosmic::Action<Message>> {
        if let Ok(mut child) = Command::new(&self.toggle).spawn() {
            std::thread::spawn(move || child.wait());
        }
        Task::none()
    }

    fn style(&self) -> Option<cosmic::iced::theme::Style> {
        Some(cosmic::applet::style())
    }
}
