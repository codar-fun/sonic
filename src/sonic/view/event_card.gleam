//// The event card and its date grouping.
////
//// Shared by the group home, the schedule views and the global list: they all
//// render the same card, and three copies of it drifted apart in the upstream
//// app before it was extracted there too.

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute.{attribute}
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{type Event, type Page}
import sonic/router
import sonic/view/badge
import sonic/view/event_time

pub fn list(events: Page(Event)) -> Element(msg) {
  case events.data {
    [] ->
      html.div([attribute.class("text-center text-gray-400 py-10")], [
        element.text("No events yet."),
      ])
    rows -> html.div([], list.map(group_by_date(rows), day_block))
  }
}

/// Events under their start date, preserving the API's ordering within a day
/// and the order dates first appear.
pub fn group_by_date(events: List(Event)) -> List(#(String, List(Event))) {
  events
  |> list.fold([], fn(acc, event) {
    let key = case string.split(event.start_time, "T") {
      [date, ..] -> date
      [] -> event.start_time
    }
    case list.key_find(acc, key) {
      Ok(existing) -> list.key_set(acc, key, list.append(existing, [event]))
      Error(_) -> list.append(acc, [#(key, [event])])
    }
  })
}

fn day_block(entry: #(String, List(Event))) -> Element(msg) {
  html.div([attribute.class("mb-4")], [
    html.div([attribute.class("flex-row-item-center mb-3")], [
      html.span(
        [
          attribute.class(
            "w-2 h-2 rounded-full border-2 border-gray-300 mr-3 shrink-0",
          ),
        ],
        [],
      ),
      html.div([attribute.class("text-lg font-semibold")], [
        element.text(heading(entry.0)),
      ]),
    ]),
    html.div([], list.map(entry.1, card)),
  ])
}

fn heading(date: String) -> String {
  case string.split(event_time.readable(date <> "T00:00:00Z"), ",") {
    [day, ..] -> day
    [] -> date
  }
}

pub fn card(event: Event) -> Element(msg) {
  html.a(
    [
      attribute.href(router.href(router.EventDetail(event.id))),
      attribute.class(
        "flex justify-between p-4 rounded-lg mb-3 shadow hover:shadow-md transition-shadow bg-[var(--background)]",
      ),
    ],
    [
      html.div([attribute.class("flex-1 min-w-0 mr-3")], [
        status_badge(event),
        html.div([attribute.class("text-lg font-semibold mt-1")], [
          element.text(event.title),
        ]),
        host_line(event),
        detail_line("uil-calender", Some(when(event))),
        detail_line("uil-location-point", where(event)),
        detail_line("uil-users-alt", group_of(event)),
      ]),
      thumbnail(event.cover),
    ],
  )
}

/// Only the states the payload asserts outright. past/ongoing/upcoming are
/// derived from a clock upstream, and guessing without one would be wrong in
/// half the world's timezones.
fn status_badge(event: Event) -> Element(msg) {
  case event.status, event.visibility {
    "cancelled", _ -> badge.view(badge.Cancel, "Cancelled")
    "pending", _ -> badge.view(badge.Pending, "Pending")
    _, "private" -> badge.view(badge.Private, "Private")
    _, _ -> element.none()
  }
}

fn host_line(event: Event) -> Element(msg) {
  case event.owner {
    Some(owner) ->
      html.div([attribute.class("text-sm mt-2")], [
        element.text(
          "hosted by " <> profile_name(owner.nickname, owner.name, owner.id),
        ),
      ])
    None -> element.none()
  }
}

fn detail_line(glyph: String, value: Option(String)) -> Element(msg) {
  case value {
    Some(text) if text != "" ->
      html.div([attribute.class("flex-row-item-center text-sm mt-1")], [
        html.i([attribute.class(glyph <> " mr-1")], []),
        html.span([attribute.class("truncate")], [element.text(text)]),
      ])
    _ -> element.none()
  }
}

fn when(event: Event) -> String {
  event_time.range_with_zone(event.start_time, event.end_time, event.timezone)
}

fn where(event: Event) -> Option(String) {
  case event.venue, event.place {
    Some(v), _ -> first_present([v.title, v.location])
    None, Some(p) -> first_present([p.title, p.formatted_address])
    None, None -> None
  }
}

fn group_of(event: Event) -> Option(String) {
  case event.group {
    Some(g) -> first_present([g.nickname, g.name])
    None -> None
  }
}

fn thumbnail(url: Option(String)) -> Element(msg) {
  case url {
    Some(src) if src != "" ->
      html.img([
        attribute.src(src),
        attribute.alt(""),
        attribute.class("w-[140px] h-[140px] rounded-lg object-cover shrink-0"),
        attribute("loading", "lazy"),
      ])
    _ -> element.none()
  }
}

fn profile_name(
  nickname: Option(String),
  name: Option(String),
  fallback: String,
) -> String {
  case nickname, name {
    Some(value), _ if value != "" -> value
    _, Some(value) if value != "" -> value
    _, _ -> fallback
  }
}

fn first_present(values: List(Option(String))) -> Option(String) {
  case values {
    [Some(value), ..] if value != "" -> Some(value)
    [_, ..rest] -> first_present(rest)
    [] -> None
  }
}
