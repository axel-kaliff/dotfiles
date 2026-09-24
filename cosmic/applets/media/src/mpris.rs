//! Every MPRIS player on the session bus with its current track, re-read whenever a player comes
//! or goes or its playback status or metadata changes. Modelled on cosmic-applet-audio's
//! mpris_subscription (System76, GPL-3.0-only).

use std::path::PathBuf;
use std::pin::Pin;

use cosmic::iced::futures::{self, SinkExt, Stream, StreamExt, channel::mpsc, stream::SelectAll};
use cosmic::iced::{Subscription, stream};
use jiff::SignedDuration;
use mpris2_zbus::enumerator::{Enumerator, Event};
use mpris2_zbus::media_player::MediaPlayer;
use mpris2_zbus::player::{PlaybackStatus, Player};
use zbus::names::OwnedBusName;
use zbus::zvariant::OwnedObjectPath;
use zbus::Connection;

#[derive(Debug, Clone)]
pub struct PlayerInfo {
    pub name: OwnedBusName,
    pub player: Player,
    pub media_player: MediaPlayer,
    pub identity: String,
    pub title: String,
    pub artist: String,
    pub album: String,
    /// Cover art the player left on disk; remote art is not fetched.
    pub art: Option<PathBuf>,
    pub length: Option<SignedDuration>,
    pub track_id: Option<OwnedObjectPath>,
    pub status: PlaybackStatus,
    pub can_go_next: bool,
    pub can_go_previous: bool,
    pub can_seek: bool,
    pub can_raise: bool,
}

impl PlayerInfo {
    pub fn playing(&self) -> bool {
        self.status == PlaybackStatus::Playing
    }

    pub fn has_track(&self) -> bool {
        !self.title.is_empty() || !self.artist.is_empty()
    }

    async fn read(name: OwnedBusName, player: Player, media_player: MediaPlayer) -> Self {
        let (metadata, status, can_go_next, can_go_previous, can_seek, can_raise, identity) = tokio::join!(
            player.metadata(),
            player.playback_status(),
            player.can_go_next(),
            player.can_go_previous(),
            player.can_seek(),
            media_player.can_raise(),
            media_player.identity(),
        );
        let metadata = metadata.ok();
        let field = |value: Option<String>| value.unwrap_or_default();
        Self {
            name,
            player,
            media_player,
            identity: identity.unwrap_or_default(),
            title: field(metadata.as_ref().and_then(|m| m.title().or_else(|| m.url().and_then(|url| file_name(&url))))),
            artist: field(metadata.as_ref().and_then(|m| m.artists()).map(|a| a.join(", "))),
            album: field(metadata.as_ref().and_then(|m| m.album())),
            art: metadata.as_ref().and_then(|m| m.art_url()).and_then(|url| art_path(&url)),
            length: metadata.as_ref().and_then(|m| m.length()).filter(|l| l.is_positive()),
            track_id: metadata.as_ref().and_then(|m| m.track_id()),
            status: status.unwrap_or(PlaybackStatus::Stopped),
            can_go_next: can_go_next.unwrap_or_default(),
            can_go_previous: can_go_previous.unwrap_or_default(),
            can_seek: can_seek.unwrap_or_default(),
            can_raise: can_raise.unwrap_or_default(),
        }
    }
}

/// A player without tags (a bare file) is labelled by its file name, the way the stock audio
/// applet does it.
fn file_name(url: &str) -> Option<String> {
    let path = url::Url::parse(url).ok()?.to_file_path().ok()?;
    Some(path.file_name()?.to_string_lossy().into_owned())
}

fn art_path(url: &str) -> Option<PathBuf> {
    let url = url::Url::parse(url).ok()?;
    (url.scheme() == "file").then(|| url.to_file_path().ok()).flatten()
}

pub fn subscription() -> Subscription<Vec<PlayerInfo>> {
    Subscription::run(|| {
        stream::channel(8, |mut output| async move {
            run(&mut output).await;
            futures::future::pending().await
        })
    })
}

type Signals = SelectAll<Pin<Box<dyn Stream<Item = ()> + Send>>>;

struct State {
    conn: Connection,
    players: Vec<(OwnedBusName, Player, MediaPlayer)>,
    /// Playback status and metadata changes of every player, merged.
    signals: Signals,
}

impl State {
    async fn add(&mut self, name: OwnedBusName) {
        let (Ok(player), Ok(media_player)) =
            (Player::new(&self.conn, name.clone()).await, MediaPlayer::new(&self.conn, name.clone()).await)
        else {
            return;
        };
        self.players.retain(|(n, _, _)| *n != name);
        self.players.push((name, player, media_player));
        self.players.sort_by(|a, b| a.0.cmp(&b.0));
        self.rebuild_signals().await;
    }

    async fn remove(&mut self, name: &OwnedBusName) {
        self.players.retain(|(n, _, _)| n != name);
        self.rebuild_signals().await;
    }

    async fn rebuild_signals(&mut self) {
        let mut signals: Signals = SelectAll::new();
        for (_, player, _) in &self.players {
            signals.push(Box::pin(player.receive_playback_status_changed().await.map(|_| ())));
            signals.push(Box::pin(player.receive_metadata_changed().await.map(|_| ())));
        }
        self.signals = signals;
    }

}

/// A free function so the awaited future borrows only the list, which is `Sync`.
async fn snapshot(players: &[(OwnedBusName, Player, MediaPlayer)]) -> Vec<PlayerInfo> {
    let reads = players.iter().map(|(n, p, m)| PlayerInfo::read(n.clone(), p.clone(), m.clone()));
    futures::future::join_all(reads).await
}

async fn run(output: &mut mpsc::Sender<Vec<PlayerInfo>>) {
    let Ok(conn) = Connection::session().await else { return };
    let Ok(enumerator) = Enumerator::new(&conn).await else { return };
    let Ok(mut changes) = enumerator.receive_changes().await else { return };
    let mut state = State { conn, players: Vec::new(), signals: SelectAll::new() };
    for name in enumerator.players().await.unwrap_or_default() {
        state.add(name).await;
    }
    loop {
        let _ = output.send(snapshot(&state.players).await).await;
        tokio::select! {
            event = changes.next() => match event {
                Some(Ok(Event::Add(name))) => state.add(name).await,
                Some(Ok(Event::Remove(name))) => state.remove(&name).await,
                Some(Err(_)) | None => return,
            },
            _ = state.signals.next(), if !state.players.is_empty() => {}
        }
    }
}
