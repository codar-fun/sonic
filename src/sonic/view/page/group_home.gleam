//// A group's event home — what `/event/:grouphandle` serves.
////
//// Two columns that stack on mobile, with the event list first in source
//// order but second on wide screens (`order-2 md:order-1`) and the group
//// sidebar the other way round. Keeping the order attributes means the mobile
//// stacking order matches the original rather than merely looking similar on a
//// desktop screen.
////
//// The left column is Upcoming/Past tabs, a search row, then events grouped
//// under a date heading. The right column leads with the group identity and
//// its member count, then the schedule link, the banner, and the venue link.

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute.{attribute}
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{type Event, type GroupDetail, type Page}
import sonic/router
import sonic/view/badge
import sonic/view/event_time

pub fn view(group: GroupDetail, events: Page(Event)) -> Element(msg) {
  html.div(
    [
      attribute.class(
        "page-width min-h-[100svh] sm:pt-8 pt-3 flex-col flex md:flex-row",
      ),
    ],
    [
      html.div([attribute.class("flex-1 md:max-w-[648px] order-2 md:order-1")], [
        tabs(group),
        search_row(group),
        event_list(events),
      ]),
      html.div(
        [
          attribute.class(
            "md:w-[328px] ml-0 flex-col flex order-1 md:order-2 md:ml-6 mb-6",
          ),
        ],
        [sidebar(group)],
      ),
    ],
  )
}

/// Upcoming / Past. Links rather than buttons, so the choice survives without
/// JavaScript; nothing reads the parameter yet, so neither is marked current.
fn tabs(group: GroupDetail) -> Element(msg) {
  let base = "text-2xl font-semibold mr-4 cursor-pointer"
  html.div([attribute.class("flex-row-item-center mb-4")], [
    html.a(
      [
        attribute.href(group_path(group) <> "?tab=upcoming"),
        attribute.class(base <> " text-gray-400"),
      ],
      [element.text("Upcoming")],
    ),
    html.a(
      [
        attribute.href(group_path(group) <> "?tab=past"),
        attribute.class(base),
      ],
      [element.text("Past")],
    ),
  ])
}

fn search_row(group: GroupDetail) -> Element(msg) {
  html.div([attribute.class("flex-row-item-center gap-2 mb-4")], [
    html.form(
      [
        attribute.method("get"),
        attribute.action("/search"),
        attribute.class("flex-1"),
      ],
      [
        html.input([
          attribute.type_("search"),
          attribute.name("keyword"),
          attribute.placeholder("Search..."),
          attribute.class(
            "w-full bg-[#f8f9f8] rounded-lg px-4 py-3 text-sm border-0",
          ),
        ]),
      ],
    ),
    icon_button(group_path(group) <> "/tracks", "uil-filter"),
    icon_button(group_path(group) <> "/schedule", "uil-calender"),
    icon_button(group_path(group) <> "/venues", "uil-rss"),
  ])
}

fn icon_button(href: String, glyph: String) -> Element(msg) {
  html.a(
    [
      attribute.href(href),
      attribute.class(
        "w-12 h-12 rounded-lg border border-gray-200 flex items-center justify-center",
      ),
    ],
    [html.i([attribute.class(glyph <> " text-xl")], [])],
  )
}

fn event_list(events: Page(Event)) -> Element(msg) {
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
fn group_by_date(events: List(Event)) -> List(#(String, List(Event))) {
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

fn card(event: Event) -> Element(msg) {
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

// --- sidebar ---------------------------------------------------------------

fn sidebar(group: GroupDetail) -> Element(msg) {
  html.div([], [
    identity(group),
    action(group_path(group) <> "/schedule", "uil-calender", "Event Schedule", [
      "bg-[#fff5e5] text-[#f28c00]",
    ]),
    banner(group.banner_image_url),
    action(group_path(group) <> "/venues", "uil-home", "Venue List", [
      "bg-[#272928] text-white",
    ]),
    about(group.bio),
  ])
}

fn identity(group: GroupDetail) -> Element(msg) {
  html.div([attribute.class("flex-row-item-center justify-between mb-3")], [
    html.div([attribute.class("flex-row-item-center min-w-0")], [
      avatar(first_present([group.image_url, group.logo_url])),
      html.div([attribute.class("font-semibold ml-2 truncate")], [
        element.text(group_name(group)),
      ]),
    ]),
    html.a(
      [
        attribute.href(group_path(group) <> "/members"),
        attribute.class("flex-row-item-center text-sm shrink-0"),
      ],
      [
        element.text(int.to_string(group.memberships_count) <> " Members"),
        html.i([attribute.class("uil-arrow-right ml-1")], []),
      ],
    ),
  ])
}

fn action(
  href: String,
  glyph: String,
  label: String,
  classes: List(String),
) -> Element(msg) {
  html.a(
    [
      attribute.href(href),
      attribute.class(
        "flex-row-item-center justify-center rounded-lg py-3 mb-3 font-semibold "
        <> string.join(classes, " "),
      ),
    ],
    [
      html.i([attribute.class(glyph <> " mr-2")], []),
      element.text(label),
    ],
  )
}

fn banner(url: Option(String)) -> Element(msg) {
  case url {
    Some(src) if src != "" ->
      html.img([
        attribute.src(src),
        attribute.alt(""),
        attribute.class("w-full h-auto rounded-lg mb-3"),
      ])
    _ -> element.none()
  }
}

fn about(value: Option(String)) -> Element(msg) {
  case value {
    Some(text) if text != "" ->
      html.div([attribute.class("text-sm whitespace-pre-wrap")], [
        element.text(text),
      ])
    _ -> element.none()
  }
}

fn avatar(url: Option(String)) -> Element(msg) {
  case url {
    Some(src) if src != "" ->
      html.img([
        attribute.src(src),
        attribute.alt(""),
        attribute.class("w-6 h-6 rounded-full object-cover shrink-0"),
      ])
    _ ->
      html.div(
        [attribute.class("w-6 h-6 rounded-full bg-gray-100 shrink-0")],
        [],
      )
  }
}

// --- naming ----------------------------------------------------------------

fn group_path(group: GroupDetail) -> String {
  "/event/"
  <> case group.name {
    Some(name) if name != "" -> name
    _ -> group.id
  }
}

fn group_name(group: GroupDetail) -> String {
  profile_name(group.nickname, group.name, group.id)
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
