//// A group's schedule, list view.
////
//// The defining behaviour upstream is grouping by start date: `ListViewData`
//// returns `groupedEventByStartDate`, and the view renders a date heading
//// followed by that day's events. Everything else about the page follows from
//// that, so this reproduces the grouping rather than a flat list that merely
//// looks similar.
////
//// The other four variants (day, week, venue, compact) are different
//// presentations of the same fetch and are not built yet.

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{type Event, type GroupDetail, type Page}
import sonic/router
import sonic/view/event_time

pub fn list_view(group: GroupDetail, events: Page(Event)) -> Element(msg) {
  html.div([attribute.class("page-width min-h-[100svh] !pt-4 !pb-12")], [
    html.div([attribute.class("text-lg font-semibold mb-4")], [
      element.text(display_name(group) <> " · Schedule"),
    ]),
    case events.data {
      [] ->
        html.div([attribute.class("text-center text-gray-400 py-10")], [
          element.text("No events scheduled."),
        ])
      rows -> html.div([], list.map(group_by_date(rows), day_block))
    },
  ])
}

/// Events grouped under their start date, preserving the API's ordering within
/// each day and the order in which dates first appear.
fn group_by_date(events: List(Event)) -> List(#(String, List(Event))) {
  events
  |> list.fold([], fn(acc, event) {
    let key = date_of(event.start_time)
    case list.key_find(acc, key) {
      Ok(existing) -> list.key_set(acc, key, list.append(existing, [event]))
      Error(_) -> list.append(acc, [#(key, [event])])
    }
  })
}

fn date_of(iso: String) -> String {
  case string.split(iso, "T") {
    [date, ..] -> date
    [] -> iso
  }
}

fn day_block(entry: #(String, List(Event))) -> Element(msg) {
  html.div([attribute.class("mb-6")], [
    html.div(
      [
        attribute.class(
          "font-semibold text-sm text-gray-500 sticky top-[48px] bg-[var(--background)] py-2",
        ),
      ],
      [element.text(heading(entry.0))],
    ),
    html.div([], list.map(entry.1, row)),
  ])
}

/// `2023-08-02` → `2 Aug 2023`. Reuses the timestamp formatter by handing it a
/// midnight time, so the month names cannot drift between the two.
fn heading(date: String) -> String {
  let readable = event_time.readable(date <> "T00:00:00Z")
  case string.split(readable, ",") {
    [day, ..] -> day
    [] -> date
  }
}

fn row(event: Event) -> Element(msg) {
  html.a(
    [
      attribute.href(router.href(router.EventDetail(event.id))),
      attribute.class(
        "flex-row-item-center justify-between p-3 rounded-lg mb-2 shadow hover:shadow-md transition-shadow bg-[var(--background)]",
      ),
    ],
    [
      html.div([attribute.class("flex-1 min-w-0")], [
        html.div([attribute.class("text-xs text-gray-500")], [
          element.text(
            time_of(event.start_time) <> "–" <> time_of(event.end_time),
          ),
        ]),
        html.div([attribute.class("font-semibold truncate mt-1")], [
          element.text(event.title),
        ]),
        venue_line(event),
      ]),
    ],
  )
}

fn time_of(iso: String) -> String {
  case string.split(iso, "T") {
    [_, rest] ->
      case string.split(rest, ":") {
        [h, m, ..] -> h <> ":" <> m
        _ -> rest
      }
    _ -> iso
  }
}

fn venue_line(event: Event) -> Element(msg) {
  let where = case event.venue, event.place {
    Some(v), _ -> first_present([v.title, v.location])
    None, Some(p) -> first_present([p.title, p.formatted_address])
    None, None -> None
  }
  case where {
    Some(text) ->
      html.div([attribute.class("text-xs text-gray-500 mt-1 truncate")], [
        element.text(text),
      ])
    None -> element.none()
  }
}

fn display_name(group: GroupDetail) -> String {
  case group.nickname, group.name {
    Some(value), _ if value != "" -> value
    _, Some(value) if value != "" -> value
    _, _ -> group.id
  }
}

fn first_present(values: List(Option(String))) -> Option(String) {
  case values {
    [Some(value), ..] if value != "" -> Some(value)
    [_, ..rest] -> first_present(rest)
    [] -> None
  }
}
