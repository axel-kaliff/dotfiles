//! Now playing (the akaliff.media bar widget): the active MPRIS player's title and artist next
//! to a play/pause mark. Left-click opens the popup with cover art, a scrubber, transport
//! buttons, the other sources and the bongocat; right-click toggles playback, middle-click
//! skips, the wheel steps tracks. The active source is the playing one unless a source was
//! picked in the popup, and that pick sticks while the player stays on the bus.

mod mpris;

use std::sync::LazyLock;
use std::time::Duration;

use cosmic::iced::platform_specific::shell::wayland::commands::popup::{destroy_popup, get_popup};
use cosmic::iced::{Alignment, ContentFit, Length, Limits, Subscription, mouse::ScrollDelta, time, window::Id};
use cosmic::prelude::*;
use cosmic::widget::{self, autosize, button, icon, mouse_area};
use jiff::SignedDuration;
use mpris2_zbus::player::PlaybackStatus;
use zbus::names::OwnedBusName;

use mpris::PlayerInfo;

const APP_ID: &str = "dev.pneuma.Media";
const LABEL_CHARS: usize = 36;
const SEEK_STEP: SignedDuration = SignedDuration::from_secs(15);
const CAT_FRAMES: [&[u8]; 2] =
    [include_bytes!("../resources/bongocat-0.png"), include_bytes!("../resources/bongocat-1.png")];
static AUTOSIZE_ID: LazyLock<widget::Id> = LazyLock::new(|| widget::Id::new("autosize-main"));

fn main() -> cosmic::iced::Result {
    cosmic::applet::run::<Applet>(())
}

#[derive(Debug, Clone, Copy)]
enum Transport {
    PlayPause,
    Next,
    Previous,
    Back,
    Forward,
}

struct Applet {
    core: cosmic::Core,
    popup: Option<Id>,
    players: Vec<PlayerInfo>,
    selected: Option<OwnedBusName>,
    position: SignedDuration,
    /// Seconds under the scrubber knob while it is being dragged.
    scrub: Option<f64>,
    cat_frame: usize,
    cat: [widget::image::Handle; 2],
}

#[derive(Debug, Clone)]
enum Message {
    Players(Vec<PlayerInfo>),
    TogglePopup,
    PopupClosed(Id),
    Transport(Transport),
    Scroll(ScrollDelta),
    Scrub(f64),
    SeekTo,
    Select(OwnedBusName),
    Raise,
    PollPosition,
    Position(Option<SignedDuration>),
    Tick,
}

fn truncate(text: &str, chars: usize) -> String {
    if text.chars().count() <= chars {
        return text.to_owned();
    }
    let mut out: String = text.chars().take(chars - 1).collect();
    out.push('…');
    out
}

fn clock(duration: SignedDuration) -> String {
    let total = duration.as_secs().max(0);
    let (h, m, s) = (total / 3600, total / 60 % 60, total % 60);
    if h > 0 { format!("{h}:{m:02}:{s:02}") } else { format!("{m}:{s:02}") }
}

/// Clamped absolute seek: per the MPRIS spec a relative seek past the end acts as Next, so a
/// forward skip near the end of an episode would jump to the next one.
async fn seek_to(info: &PlayerInfo, target: SignedDuration) {
    let (Some(track), Some(length)) = (&info.track_id, info.length) else { return };
    let target = target.max(SignedDuration::ZERO).min(length);
    let _ = info.player.inner().call::<_, _, ()>("SetPosition", &(track, target.as_micros() as i64)).await;
}

impl Applet {
    fn active(&self) -> Option<&PlayerInfo> {
        if let Some(name) = &self.selected {
            if let Some(player) = self.players.iter().find(|p| p.name == *name) {
                return Some(player);
            }
        }
        // Playing beats paused beats the rest; among equals the first by bus name.
        self.players.iter().rev().max_by_key(|p| (p.playing(), p.status == PlaybackStatus::Paused, p.has_track()))
    }

    fn poll_position(&self) -> Task<cosmic::Action<Message>> {
        let Some(active) = self.active().cloned() else { return Task::none() };
        cosmic::task::future(async move { Message::Position(active.player.position().await.ok().flatten()) })
    }

    fn transport(&self, action: Transport) -> Task<cosmic::Action<Message>> {
        let Some(active) = self.active().cloned() else { return Task::none() };
        let position = self.position;
        cosmic::task::future(async move {
            match action {
                Transport::PlayPause => drop(active.player.play_pause().await),
                Transport::Next => drop(active.player.next().await),
                Transport::Previous => drop(active.player.previous().await),
                Transport::Back => seek_to(&active, position - SEEK_STEP).await,
                Transport::Forward => seek_to(&active, position + SEEK_STEP).await,
            }
            Message::PollPosition
        })
    }

    fn header<'a>(&self, active: &'a PlayerInfo) -> Element<'a, Message> {
        let art: Element<'a, Message> = match &active.art {
            Some(path) => widget::image(widget::image::Handle::from_path(path))
                .width(64)
                .height(64)
                .content_fit(ContentFit::Cover)
                .into(),
            None => widget::container(icon::from_name("audio-x-generic-symbolic").size(32)).center_x(64).center_y(64).into(),
        };
        let mut text = widget::column::with_capacity(3)
            .spacing(2)
            .push(widget::text::body(truncate(&active.title, 40)).font(cosmic::font::bold()));
        if !active.artist.is_empty() {
            text = text.push(widget::text::caption(truncate(&active.artist, 48)));
        }
        if !active.album.is_empty() {
            text = text.push(widget::text::caption(truncate(&active.album, 48)));
        }
        widget::row::with_capacity(2)
            .spacing(12)
            .align_y(Alignment::Center)
            .push(mouse_area(art).on_press(Message::Raise))
            .push(text)
            .into()
    }

    fn scrubber<'a>(&self, active: &PlayerInfo) -> Option<Element<'a, Message>> {
        let length = active.length.filter(|_| active.can_seek)?;
        let shown = self.scrub.unwrap_or(self.position.as_secs_f64());
        let slider = widget::slider(0.0..=length.as_secs_f64(), shown, Message::Scrub).on_release(Message::SeekTo);
        let times = widget::row::with_capacity(3)
            .push(widget::text::caption(clock(SignedDuration::from_secs_f64(shown))))
            .push(widget::Space::new().width(Length::Fill))
            .push(widget::text::caption(clock(length)));
        Some(widget::column::with_capacity(2).spacing(2).push(slider).push(times).into())
    }

    fn controls<'a>(&self, active: &PlayerInfo) -> Element<'a, Message> {
        let control = |name: &'static str, enabled: bool, action: Transport| {
            button::icon(icon::from_name(name)).on_press_maybe(enabled.then_some(Message::Transport(action)))
        };
        let seekable = active.can_seek && active.length.is_some();
        let play = if active.playing() { "media-playback-pause-symbolic" } else { "media-playback-start-symbolic" };
        widget::row::with_capacity(5)
            .spacing(6)
            .align_y(Alignment::Center)
            .push(control("media-skip-backward-symbolic", active.can_go_previous, Transport::Previous))
            .push(control("media-seek-backward-symbolic", seekable, Transport::Back))
            .push(button::icon(icon::from_name(play)).large().on_press(Message::Transport(Transport::PlayPause)))
            .push(control("media-seek-forward-symbolic", seekable, Transport::Forward))
            .push(control("media-skip-forward-symbolic", active.can_go_next, Transport::Next))
            .into()
    }

    fn sources<'a>(&self, active: &PlayerInfo) -> Element<'a, Message> {
        let mut list = widget::column::with_capacity(self.players.len()).spacing(2);
        for player in &self.players {
            let mark = if player.playing() { "media-playback-start-symbolic" } else { "media-playback-pause-symbolic" };
            let title = if player.title.is_empty() { player.identity.clone() } else { player.title.clone() };
            let detail = if player.artist.is_empty() { player.identity.clone() } else { player.artist.clone() };
            let row = widget::row::with_capacity(2)
                .spacing(8)
                .align_y(Alignment::Center)
                .push(icon::from_name(mark).size(16))
                .push(
                    widget::column::with_capacity(2)
                        .push(widget::text::body(truncate(&title, 40)))
                        .push(widget::text::caption(truncate(&detail, 48))),
                );
            list = list.push(
                button::custom(row)
                    .width(Length::Fill)
                    .padding([6, 8])
                    .class(cosmic::theme::Button::MenuItem)
                    .selected(player.name == active.name)
                    .on_press(Message::Select(player.name.clone())),
            );
        }
        list.into()
    }
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
        let cat = CAT_FRAMES.map(widget::image::Handle::from_bytes);
        let applet = Self {
            core,
            popup: None,
            players: Vec::new(),
            selected: None,
            position: SignedDuration::ZERO,
            scrub: None,
            cat_frame: 0,
            cat,
        };
        (applet, Task::none())
    }

    fn on_close_requested(&self, id: Id) -> Option<Message> {
        Some(Message::PopupClosed(id))
    }

    fn view(&self) -> Element<'_, Message> {
        let Some(active) = self.active().filter(|p| p.has_track()) else {
            // A zero-size frame would unmap the surface for good; a sliver keeps it resizable.
            return widget::Space::new().width(1).height(1).into();
        };
        let mark = if active.playing() { "media-playback-pause-symbolic" } else { "media-playback-start-symbolic" };
        let mut label = active.title.clone();
        if !active.artist.is_empty() {
            label.push_str("  ·  ");
            label.push_str(&active.artist);
        }
        let content = widget::row::with_capacity(2)
            .spacing(6)
            .height(Length::Fill)
            .align_y(Alignment::Center)
            .push(icon::from_name(mark).size(14))
            .push(self.core.applet.text(truncate(&label, LABEL_CHARS)));
        let height = self.core.applet.suggested_window_size().1.get() as f32;
        let button = button::custom(content)
            .padding([0, self.core.applet.suggested_padding(true).1])
            .height(Length::Fixed(height))
            .class(cosmic::theme::Button::AppletIcon)
            .on_press(Message::TogglePopup);
        mouse_area(autosize::autosize(button, AUTOSIZE_ID.clone()))
            .on_right_press(Message::Transport(Transport::PlayPause))
            .on_middle_press(Message::Transport(Transport::Next))
            .on_scroll(Message::Scroll)
            .into()
    }

    fn view_window(&self, _id: Id) -> Element<'_, Message> {
        let Some(active) = self.active() else {
            return self.core.applet.popup_container(widget::text::body("Nothing playing")).into();
        };
        let mut column = widget::column::with_capacity(6).spacing(12).padding(12).push(self.header(active));
        if let Some(scrubber) = self.scrubber(active) {
            column = column.push(scrubber);
        }
        column = column.push(widget::container(self.controls(active)).width(Length::Fill).center_x(Length::Fill));
        if self.players.len() > 1 {
            column = column.push(widget::divider::horizontal::default()).push(self.sources(active));
        }
        // Bongocat from caelestia-dots/shell (soramanew), bopping while music plays.
        column = column.push(
            widget::image(self.cat[self.cat_frame].clone()).width(Length::Fill).height(72).content_fit(ContentFit::Contain),
        );
        self.core.applet.popup_container(column).into()
    }

    fn subscription(&self) -> Subscription<Message> {
        let mut subscriptions = vec![mpris::subscription().map(Message::Players)];
        if self.popup.is_some() && self.active().is_some_and(PlayerInfo::playing) {
            subscriptions.push(time::every(Duration::from_secs(1)).map(|_| Message::PollPosition));
            subscriptions.push(time::every(Duration::from_millis(300)).map(|_| Message::Tick));
        }
        Subscription::batch(subscriptions)
    }

    fn update(&mut self, message: Message) -> Task<cosmic::Action<Message>> {
        match message {
            Message::Players(players) => {
                self.players = players;
                if self.selected.as_ref().is_some_and(|name| !self.players.iter().any(|p| p.name == *name)) {
                    self.selected = None;
                }
                if self.popup.is_some() {
                    return self.poll_position();
                }
            }
            Message::TogglePopup => {
                return match self.popup.take() {
                    Some(id) => destroy_popup(id),
                    None => {
                        let id = Id::unique();
                        self.popup = Some(id);
                        let mut settings = self.core.applet.get_popup_settings(
                            self.core.main_window_id().unwrap(),
                            id,
                            None,
                            None,
                            None,
                        );
                        settings.positioner.size_limits =
                            Limits::NONE.min_width(320.0).max_width(360.0).min_height(60.0).max_height(640.0);
                        Task::batch([get_popup(settings), self.poll_position()])
                    }
                };
            }
            Message::PopupClosed(id) => {
                if self.popup == Some(id) {
                    self.popup = None;
                }
            }
            Message::Transport(action) => return self.transport(action),
            Message::Scroll(delta) => {
                let y = match delta {
                    ScrollDelta::Lines { y, .. } | ScrollDelta::Pixels { y, .. } => y,
                };
                if y > 0.0 {
                    return self.transport(Transport::Previous);
                } else if y < 0.0 {
                    return self.transport(Transport::Next);
                }
            }
            Message::Scrub(seconds) => self.scrub = Some(seconds),
            Message::SeekTo => {
                if let (Some(seconds), Some(active)) = (self.scrub.take(), self.active().cloned()) {
                    let target = SignedDuration::from_secs_f64(seconds);
                    self.position = target;
                    return cosmic::task::future(async move {
                        seek_to(&active, target).await;
                        Message::PollPosition
                    });
                }
            }
            Message::Select(name) => {
                self.selected = Some(name);
                return self.poll_position();
            }
            Message::Raise => {
                if let Some(active) = self.active().filter(|p| p.can_raise).cloned() {
                    return Task::batch([
                        cosmic::task::future(async move {
                            let _ = active.media_player.raise().await;
                            Message::PollPosition
                        }),
                        self.update(Message::TogglePopup),
                    ]);
                }
            }
            Message::PollPosition => return self.poll_position(),
            Message::Position(position) => {
                if self.scrub.is_none() {
                    self.position = position.unwrap_or(SignedDuration::ZERO);
                }
            }
            Message::Tick => self.cat_frame ^= 1,
        }
        Task::none()
    }

    fn style(&self) -> Option<cosmic::iced::theme::Style> {
        Some(cosmic::applet::style())
    }
}
