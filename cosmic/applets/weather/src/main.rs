//! Weather (the omarchy.weather bar widget): the temperature next to a condition icon; the popup
//! adds feels-like, humidity, wind and three days of forecast. Data is Open-Meteo, metric. The
//! place is ~/.config/pneuma/weather.json {"name","latitude","longitude"} or, without one,
//! wttr.in's guess from the IP address, kept for the session. Middle-click refreshes,
//! right-click posts the summary as a notification.

use std::path::PathBuf;
use std::process::Command;
use std::sync::LazyLock;
use std::time::Duration;

use cosmic::iced::platform_specific::shell::wayland::commands::popup::{destroy_popup, get_popup};
use cosmic::iced::widget::text::Wrapping;
use cosmic::iced::{Alignment, Length, Limits, Subscription, time, window::Id};
use cosmic::prelude::*;
use cosmic::widget::{self, autosize, button, icon, mouse_area};
use serde::Deserialize;

const APP_ID: &str = "dev.pneuma.Weather";
const REFRESH: Duration = Duration::from_secs(30 * 60);
static AUTOSIZE_ID: LazyLock<widget::Id> = LazyLock::new(|| widget::Id::new("autosize-main"));

fn main() -> cosmic::iced::Result {
    cosmic::applet::run::<Applet>(())
}

#[derive(Debug, Clone, Deserialize)]
struct Place {
    name: String,
    latitude: f64,
    longitude: f64,
}

#[derive(Debug, Clone, Deserialize)]
struct Forecast {
    current: Current,
    daily: Daily,
}

#[derive(Debug, Clone, Deserialize)]
struct Current {
    temperature_2m: f64,
    apparent_temperature: f64,
    relative_humidity_2m: f64,
    wind_speed_10m: f64,
    weather_code: u32,
    is_day: u8,
}

#[derive(Debug, Clone, Deserialize)]
struct Daily {
    time: Vec<String>,
    weather_code: Vec<u32>,
    temperature_2m_max: Vec<f64>,
    temperature_2m_min: Vec<f64>,
}

/// Icon-theme name and label for a WMO weather code.
fn condition(code: u32, night: bool) -> (String, &'static str) {
    let (base, label, has_night) = match code {
        0 => ("weather-clear", "Clear", true),
        1 | 2 => ("weather-few-clouds", "Partly cloudy", true),
        3 => ("weather-overcast", "Overcast", false),
        45 | 48 => ("weather-fog", "Fog", false),
        51..=57 | 61 => ("weather-showers-scattered", "Light rain", true),
        63..=67 | 80..=82 => ("weather-showers", "Rain", true),
        71..=77 | 85 | 86 => ("weather-snow", "Snow", true),
        95..=99 => ("weather-storm", "Thunderstorm", true),
        _ => ("weather-overcast", "Cloudy", false),
    };
    let suffix = if night && has_night { "-night-symbolic" } else { "-symbolic" };
    (format!("{base}{suffix}"), label)
}

fn degrees(value: f64) -> String {
    format!("{}°", value.round() as i64)
}

fn weekday(date: &str) -> String {
    date.parse::<jiff::civil::Date>().map(|d| d.strftime("%A").to_string()).unwrap_or_default()
}

async fn curl(url: String) -> Option<Vec<u8>> {
    let run = tokio::process::Command::new("curl").args(["-fsS", "--max-time", "10", &url]).output();
    let output = tokio::time::timeout(Duration::from_secs(15), run).await.ok()?.ok()?;
    output.status.success().then_some(output.stdout)
}

async fn locate(config: PathBuf) -> Option<Place> {
    if let Some(place) = std::fs::read(&config).ok().and_then(|raw| serde_json::from_slice(&raw).ok()) {
        return Some(place);
    }
    #[derive(Deserialize)]
    struct Wttr {
        nearest_area: Vec<Area>,
    }
    #[derive(Deserialize)]
    struct Area {
        latitude: String,
        longitude: String,
        #[serde(rename = "areaName")]
        area_name: Vec<Named>,
    }
    #[derive(Deserialize)]
    struct Named {
        value: String,
    }
    let wttr: Wttr = serde_json::from_slice(&curl("https://wttr.in/?format=j1".into()).await?).ok()?;
    let area = wttr.nearest_area.into_iter().next()?;
    Some(Place {
        name: area.area_name.into_iter().next().map(|n| n.value).unwrap_or_default(),
        latitude: area.latitude.parse().ok()?,
        longitude: area.longitude.parse().ok()?,
    })
}

async fn fetch(place: Place) -> Option<Forecast> {
    let url = format!(
        "https://api.open-meteo.com/v1/forecast?latitude={}&longitude={}\
         &current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day\
         &daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=4",
        place.latitude, place.longitude
    );
    serde_json::from_slice(&curl(url).await?).ok()
}

struct Applet {
    core: cosmic::Core,
    popup: Option<Id>,
    config: PathBuf,
    place: Option<Place>,
    forecast: Option<Forecast>,
}

#[derive(Debug, Clone)]
enum Message {
    Refresh,
    Located(Option<Place>),
    Fetched(Option<Forecast>),
    TogglePopup,
    PopupClosed(Id),
    Notify,
}

impl Applet {
    fn refresh(&self) -> Task<cosmic::Action<Message>> {
        match self.place.clone() {
            Some(place) => cosmic::task::future(async move { Message::Fetched(fetch(place).await) }),
            None => {
                let config = self.config.clone();
                cosmic::task::future(async move { Message::Located(locate(config).await) })
            }
        }
    }

    fn summary(&self) -> Option<String> {
        let current = &self.forecast.as_ref()?.current;
        let (_, label) = condition(current.weather_code, current.is_day == 0);
        Some(format!(
            "{} {label}, feels like {} · humidity {}% · wind {} km/h",
            degrees(current.temperature_2m),
            degrees(current.apparent_temperature),
            current.relative_humidity_2m.round(),
            current.wind_speed_10m.round()
        ))
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
        let config = std::env::var_os("XDG_CONFIG_HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|| PathBuf::from(std::env::var_os("HOME").unwrap_or_default()).join(".config"))
            .join("pneuma/weather.json");
        let applet = Self { core, popup: None, config, place: None, forecast: None };
        let refresh = applet.refresh();
        (applet, refresh)
    }

    fn on_close_requested(&self, id: Id) -> Option<Message> {
        Some(Message::PopupClosed(id))
    }

    fn view(&self) -> Element<'_, Message> {
        let Some(forecast) = &self.forecast else {
            // A zero-size frame would unmap the surface for good; a sliver keeps it resizable.
            return widget::Space::new().width(1).height(1).into();
        };
        let current = &forecast.current;
        let (name, _) = condition(current.weather_code, current.is_day == 0);
        let content = widget::row::with_capacity(2)
            .spacing(6)
            .height(Length::Fill)
            .align_y(Alignment::Center)
            .push(icon::from_name(name).size(16))
            .push(self.core.applet.text(degrees(current.temperature_2m)).wrapping(Wrapping::None));
        let height = self.core.applet.suggested_window_size().1.get() as f32;
        let button = button::custom(content)
            .padding([0, self.core.applet.suggested_padding(true).1])
            .height(Length::Fixed(height))
            .class(cosmic::theme::Button::AppletIcon)
            .on_press(Message::TogglePopup);
        mouse_area(autosize::autosize(button, AUTOSIZE_ID.clone()))
            .on_middle_press(Message::Refresh)
            .on_right_press(Message::Notify)
            .into()
    }

    fn view_window(&self, _id: Id) -> Element<'_, Message> {
        let Some(forecast) = &self.forecast else {
            return self.core.applet.popup_container(widget::text::body("No forecast yet")).into();
        };
        let current = &forecast.current;
        let (name, label) = condition(current.weather_code, current.is_day == 0);
        let place = self.place.as_ref().map(|p| p.name.as_str()).unwrap_or_default();
        let hero = widget::row::with_capacity(2)
            .spacing(12)
            .align_y(Alignment::Center)
            .push(icon::from_name(name).size(48))
            .push(
                widget::column::with_capacity(2)
                    .push(widget::text::title2(degrees(current.temperature_2m)))
                    .push(widget::text::body(label)),
            );
        let details = format!(
            "Feels like {} · Humidity {}% · Wind {} km/h",
            degrees(current.apparent_temperature),
            current.relative_humidity_2m.round(),
            current.wind_speed_10m.round()
        );
        let mut column = widget::column::with_capacity(8)
            .spacing(8)
            .padding(12)
            .push(widget::text::caption(place))
            .push(hero)
            .push(widget::text::caption(details))
            .push(widget::divider::horizontal::default());
        // The first daily entry is today; the next three are the forecast.
        let daily = &forecast.daily;
        for i in 1..daily.time.len().min(4) {
            let (name, _) = condition(daily.weather_code[i], false);
            column = column.push(
                widget::row::with_capacity(4)
                    .spacing(8)
                    .align_y(Alignment::Center)
                    .push(widget::text::body(weekday(&daily.time[i])).width(Length::Fixed(100.0)))
                    .push(icon::from_name(name).size(20))
                    .push(widget::Space::new().width(Length::Fill))
                    .push(widget::text::body(format!(
                        "{} / {}",
                        degrees(daily.temperature_2m_max[i]),
                        degrees(daily.temperature_2m_min[i])
                    ))),
            );
        }
        self.core.applet.popup_container(column).into()
    }

    fn subscription(&self) -> Subscription<Message> {
        time::every(REFRESH).map(|_| Message::Refresh)
    }

    fn update(&mut self, message: Message) -> Task<cosmic::Action<Message>> {
        match message {
            Message::Refresh => return self.refresh(),
            Message::Located(place) => {
                self.place = place;
                if self.place.is_some() {
                    return self.refresh();
                }
            }
            Message::Fetched(forecast) => {
                if forecast.is_some() {
                    self.forecast = forecast;
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
                            Limits::NONE.min_width(280.0).max_width(360.0).min_height(60.0).max_height(500.0);
                        get_popup(settings)
                    }
                };
            }
            Message::PopupClosed(id) => {
                if self.popup == Some(id) {
                    self.popup = None;
                }
            }
            Message::Notify => {
                if let Some(summary) = self.summary() {
                    if let Ok(mut child) = Command::new("notify-send").args(["-a", "Weather", "Weather", &summary]).spawn() {
                        std::thread::spawn(move || child.wait());
                    }
                }
            }
        }
        Task::none()
    }

    fn style(&self) -> Option<cosmic::iced::theme::Style> {
        Some(cosmic::applet::style())
    }
}
