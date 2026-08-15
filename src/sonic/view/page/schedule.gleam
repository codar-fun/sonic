//// A group's schedule.
////
//// Three presentations of one fetch. The defining behaviour upstream is
//// grouping by start date: a date heading followed by that day's events, each
//// as a card. Everything else follows from that, so this reproduces the
//// grouping rather than a flat list that merely looks similar.
////
//// The window is a date range, not a page of results: the list view covers
//// the current week, compact and venue a single day. Asking by page count
//// instead returned the group's entire history under a heading that says this
//// week — which is how this page came to be showing hundreds of past events.

import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{type Event, type GroupDetail, type Page}
import sonic/router
import sonic/view/event_card
import sonic/view/event_time
import sonic/view/image

/// How a day's events are laid out. The fetch and the grouping are identical
/// across all of these; only this differs, which is why they are one module.
pub type Layout {
  /// One card per event with time, venue and host.
  ListLayout
  /// Title and time only — the embed-sized variant.
  CompactLayout
  /// Grouped by venue within each day.
  VenueLayout
}

pub fn list_view(group: GroupDetail, events: Page(Event)) -> Element(msg) {
  view(group, events, ListLayout)
}

pub fn compact_view(group: GroupDetail, events: Page(Event)) -> Element(msg) {
  view(group, events, CompactLayout)
}

pub fn venue_view(group: GroupDetail, events: Page(Event)) -> Element(msg) {
  view(group, events, VenueLayout)
}

fn view(
  group: GroupDetail,
  events: Page(Event),
  layout: Layout,
) -> Element(msg) {
  html.div(
    [attribute.class("min-h-[100svh] relative pb-12 bg-[#F8F9F8] w-full")],
    [
      html.div([attribute.class("schedule-bg")], []),
      html.div([attribute.class("page-width z-10 relative")], [
        title_row(group),
        tool_bar(group, layout),
        body(events, layout),
      ]),
    ],
  )
}

fn title_row(group: GroupDetail) -> Element(msg) {
  html.div(
    [
      attribute.class(
        "py-3 sm:py-5 max-w-[100vw] flex flex-row justify-between",
      ),
    ],
    [
      html.div([attribute.class("sm:text-2xl text-xl")], [
        html.a(
          [
            attribute.href("/event/" <> handle(group)),
            attribute.class("font-semibold text-[#6CD7B2] mr-2"),
          ],
          [element.text(display_name(group))],
        ),
        html.span([attribute.class("whitespace-nowrap")], [
          element.text("Event Schedule"),
        ]),
      ]),
    ],
  )
}

/// Month label and the view switcher. Upstream also carries month arrows and a
/// Filter panel; both drive state this page does not hold yet, and a control
/// that visibly does nothing is worse than one that is not there.
fn tool_bar(group: GroupDetail, layout: Layout) -> Element(msg) {
  html.div(
    [attribute.class("flex flex-row justify-between items-center flex-wrap")],
    [
      html.div(
        [attribute.class("schedule-month text-base sm:text-lg mr-2 font-semibold")],
        [element.text(month_label(option.unwrap(group.timezone, "UTC")))],
      ),
      html.div(
        [
          attribute.class(
            "flex-row-item-center rounded-[8px] bg-[#ececec] py-[5px] px-[5px]",
          ),
        ],
        list.map(
          [
            #("Compact", "/schedule/compact", CompactLayout, "w-[94px]"),
            #("Venue", "/schedule/venue", VenueLayout, "w-[74px]"),
            #("List", "/schedule/list", ListLayout, "w-[74px]"),
          ],
          fn(tab) {
            let #(label, path, tab_layout, width) = tab
            switcher_tab(
              label:,
              href: "/event/" <> handle(group) <> path,
              width:,
              active: tab_layout == layout,
            )
          },
        ),
      ),
    ],
  )
}

fn switcher_tab(
  label label: String,
  href href: String,
  width width: String,
  active active: Bool,
) -> Element(msg) {
  html.a(
    [
      attribute.href(href),
      attribute.class(
        "font-semibold inline-flex items-center justify-center whitespace-nowrap transition-colors h-9 rounded-[6px] px-3 "
        <> width
        <> case active {
          // The selected tab is a raised white pill; the rest are flat grey.
          True -> " bg-white text-[#272928] shadow"
          False -> " text-[#C3C7C3] hover:text-[#272928]"
        },
      ),
    ],
    [element.text(label)],
  )
}

fn body(events: Page(Event), layout: Layout) -> Element(msg) {
  case events.data {
    [] ->
      html.div([attribute.class("text-center text-gray-400 py-10")], [
        element.text("No events scheduled."),
      ])
    rows ->
      html.div(
        [],
        list.map(event_card.group_by_date(rows), fn(entry) {
          day_block(entry, layout)
        }),
      )
  }
}

/// The day heading carries the date as its id, matching upstream — that is
/// what the day navigator scrolls to.
fn day_block(entry: #(String, List(Event)), layout: Layout) -> Element(msg) {
  let label = heading(entry.0)
  html.div([attribute.id(label)], [
    html.div([attribute.class("font-semibold mb-1 mt-6")], [
      element.text(label),
    ]),
    case layout {
      VenueLayout -> html.div([], list.map(by_venue(entry.1), venue_block))
      _ -> html.div([], list.map(entry.1, fn(event) { row(event, layout) }))
    },
  ])
}

/// `2026-08-10` → `Aug 10`. The parser wants a full timestamp, so a grouping
/// key gets a midnight one — the time is discarded either way.
fn heading(date: String) -> String {
  event_time.short_day(date <> "T00:00:00Z")
}

/// Events of one day grouped under their venue, for the venue layout.
fn by_venue(events: List(Event)) -> List(#(String, List(Event))) {
  events
  |> list.fold([], fn(acc, event) {
    let key = venue_name(event)
    case list.key_find(acc, key) {
      Ok(existing) -> list.key_set(acc, key, list.append(existing, [event]))
      Error(_) -> list.append(acc, [#(key, [event])])
    }
  })
}

fn venue_block(entry: #(String, List(Event))) -> Element(msg) {
  html.div([attribute.class("mb-3")], [
    html.div([attribute.class("text-xs font-semibold text-gray-400 mb-1")], [
      element.text(entry.0),
    ]),
    html.div([], list.map(entry.1, fn(event) { row(event, VenueLayout) })),
  ])
}

fn venue_name(event: Event) -> String {
  case where_line(event) {
    Some(name) -> name
    None -> "Unspecified"
  }
}

fn row(event: Event, layout: Layout) -> Element(msg) {
  html.div([attribute.class("flex flex-row text-xs sm:text-base")], [
    html.div([attribute.class("pb-2 flex-1 relative")], [
      html.a(
        [
          attribute.href(router.href(router.EventDetail(event.id))),
          attribute.class(
            "flex flex-col flex-nowrap !items-start bg-white py-2 px-4 shadow rounded-[4px] cursor-pointer relative sm:duration-200 sm:hover:scale-105",
          ),
        ],
        [
          // The track's colour stripe down the left edge. White when the event
          // has no track, which is how upstream renders it too — the stripe is
          // still there, it just does not read as a category.
          html.i(
            [
              attribute.class("h-full w-0.5 left-0 top-0 absolute"),
              attribute.styles([#("background", track_colour(event))]),
            ],
            [],
          ),
          html.div(
            [attribute.class("flex-1 font-semibold mr-4 mb-2 flex-row-item-center")],
            [element.text(event.title)],
          ),
          html.div([attribute.class("flex-1 text-xs text-gray-500 mb-2")], [
            html.i([attribute.class("uil-calender mr-1")], []),
            element.text(time_line(event)),
          ]),
          case layout {
            // The venue layout prints the venue as a heading already, and the
            // compact layout has no room for it.
            ListLayout -> where_element(event)
            _ -> element.none()
          },
          case layout {
            ListLayout -> host_line(event)
            _ -> element.none()
          },
        ],
      ),
    ]),
  ])
}

/// `Aug 10, 10:00 - 11:00 GMT+7` — in the event's own zone, not the server's.
fn time_line(event: Event) -> String {
  event_time.short_day(event.start_time)
  <> ", "
  <> event_time.in_zone_range(event.start_time, event.end_time, event.timezone)
}

fn where_element(event: Event) -> Element(msg) {
  case where_line(event) {
    Some(text) ->
      html.div([attribute.class("flex-1 text-xs text-gray-500 mb-2")], [
        html.i([attribute.class("uil-location-point mr-1")], []),
        element.text(text),
      ])
    None -> element.none()
  }
}

/// The venue's name, or the place's when there is no venue. Upstream prints
/// one name, not both: the venue name already ends in the building it is in.
fn where_line(event: Event) -> Option(String) {
  let venue = case event.venue {
    Some(v) -> first_present([v.title, v.location])
    None -> None
  }
  case venue {
    Some(_) -> venue
    None ->
      case event.place {
        Some(p) -> first_present([p.title, p.address])
        None -> None
      }
  }
}

fn host_line(event: Event) -> Element(msg) {
  case event.owner {
    Some(owner) ->
      html.div([attribute.class("text-xs text-gray-500 flex-row-item-center")], [
        html.div([attribute.class("flex-row-item-center")], [
          element.text("by"),
          image.avatar_or_default(
            owner.image_url,
            owner.id,
            "w-4 h-4 rounded-full mx-1",
          ),
          element.text(name_of(owner.nickname, owner.name, owner.id)),
        ]),
      ])
    None -> element.none()
  }
}

/// Upstream colours the stripe from the event's track. Tracks carry no colour
/// on this API, so an event with one gets the site's accent and everything else
/// gets white — the same shape, without inventing a palette that would not
/// match anyway.
fn track_colour(event: Event) -> String {
  case event.track {
    Some(_) -> "#6CD7B2"
    None -> "#fff"
  }
}

fn handle(group: GroupDetail) -> String {
  case group.name {
    Some(value) if value != "" -> value
    _ -> group.id
  }
}

fn display_name(group: GroupDetail) -> String {
  case group.nickname, group.name {
    Some(value), _ if value != "" -> value
    _, Some(value) if value != "" -> value
    _, _ -> group.id
  }
}

fn name_of(
  nickname: Option(String),
  name: Option(String),
  fallback: String,
) -> String {
  case first_present([nickname, name]) {
    Some(value) -> value
    None -> fallback
  }
}

fn first_present(values: List(Option(String))) -> Option(String) {
  case values {
    [Some(value), ..] if value != "" -> Some(value)
    [_, ..rest] -> first_present(rest)
    [] -> None
  }
}

@external(javascript, "../../../sonic_ffi.mjs", "month_label")
fn month_label(zone: String) -> String
