//// A group's event home — what `/event/:grouphandle` serves.
////
//// Layout follows seastar-app's `GroupEventHome.tsx`: a two-column flex that
//// stacks on mobile, with the event list first in source order but second on
//// wide screens (`order-2 md:order-1`) and the group sidebar the other way
//// round. Keeping the order attributes means the mobile stacking order matches
//// the original rather than merely looking similar on a desktop screen.

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{type Event, type GroupDetail, type Page}
import sonic/router
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

fn sidebar(group: GroupDetail) -> Element(msg) {
  html.div([], [
    banner(group.banner_image_url),
    html.div([attribute.class("flex-row-item-center mt-3 gap-2")], [
      avatar(first_present([group.image_url, group.logo_url])),
      html.div(
        [
          attribute.class(
            "font-semibold whitespace-nowrap max-w-[220px] overflow-hidden overflow-ellipsis",
          ),
        ],
        [element.text(display_name(group))],
      ),
    ]),
    line(group.location),
    line(dates(group)),
    html.div([attribute.class("flex-row-item-center mt-3 gap-2 text-xs")], [
      element.text(
        int.to_string(group.events_count)
        <> " events · "
        <> int.to_string(group.memberships_count)
        <> " members",
      ),
    ]),
    bio(group.bio),
  ])
}

fn event_list(events: Page(Event)) -> Element(msg) {
  case events.data {
    [] ->
      html.div([attribute.class("text-center text-gray-400 py-10")], [
        element.text("No events yet."),
      ])
    rows -> html.div([attribute.class("w-full mb-3")], list.map(rows, card))
  }
}

fn card(event: Event) -> Element(msg) {
  html.a(
    [
      attribute.href(router.href(router.EventDetail(event.id))),
      attribute.class(
        "flex-row-item-center justify-between p-3 rounded-lg mb-3 shadow hover:shadow-md transition-shadow bg-[var(--background)]",
      ),
    ],
    [
      html.div([attribute.class("flex-1 min-w-0")], [
        html.div([attribute.class("text-xs text-gray-500")], [
          element.text(event_time.range(event.start_time, event.end_time)),
        ]),
        html.div([attribute.class("font-semibold truncate mt-1")], [
          element.text(event.title),
        ]),
        location_line(event),
      ]),
      thumbnail(event.cover),
    ],
  )
}

fn location_line(event: Event) -> Element(msg) {
  let where = case event.place, event.venue {
    Some(place), _ -> first_present([place.title, place.formatted_address])
    None, Some(venue) -> first_present([venue.title, venue.location])
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

fn thumbnail(url: Option(String)) -> Element(msg) {
  case url {
    Some(src) if src != "" ->
      html.img([
        attribute.src(src),
        attribute.alt(""),
        attribute.class("w-16 h-16 rounded-lg object-cover ml-3 shrink-0"),
      ])
    _ -> element.none()
  }
}

fn banner(url: Option(String)) -> Element(msg) {
  case url {
    Some(src) if src != "" ->
      html.img([
        attribute.src(src),
        attribute.alt(""),
        attribute.class("w-full h-auto rounded-lg"),
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
        attribute.class("w-8 h-8 rounded-full object-cover shrink-0"),
      ])
    _ ->
      html.div(
        [attribute.class("w-8 h-8 rounded-full bg-gray-100 shrink-0")],
        [],
      )
  }
}

fn line(value: Option(String)) -> Element(msg) {
  case value {
    Some(text) if text != "" ->
      html.div([attribute.class("text-xs text-gray-500 mt-2")], [
        element.text(text),
      ])
    _ -> element.none()
  }
}

fn bio(value: Option(String)) -> Element(msg) {
  case value {
    Some(text) if text != "" ->
      html.div([attribute.class("text-sm mt-3 whitespace-pre-wrap")], [
        element.text(text),
      ])
    _ -> element.none()
  }
}

fn dates(group: GroupDetail) -> Option(String) {
  case group.start_date, group.end_date {
    Some(start), Some(end) -> Some(event_time.range(start, end))
    Some(start), None -> Some(event_time.readable(start))
    _, _ -> None
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
