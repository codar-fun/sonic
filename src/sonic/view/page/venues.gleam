//// A group's venues.

import gleam/int
import gleam/list
import gleam/option.{type Option, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{type GroupDetail, type VenueDetail}

pub fn view(group: GroupDetail) -> Element(msg) {
  html.div([attribute.class("page-width min-h-[100svh] !pt-4 !pb-12")], [
    html.div([attribute.class("text-lg font-semibold mb-4")], [
      element.text(group_name(group) <> " · Venues"),
    ]),
    case group.venues {
      [] ->
        html.div([attribute.class("text-center text-gray-400 py-10")], [
          element.text("No venues yet."),
        ])
      rows ->
        html.div(
          [attribute.class("grid grid-cols-1 sm:grid-cols-2 gap-3")],
          list.map(rows, card),
        )
    },
  ])
}

fn card(venue: VenueDetail) -> Element(msg) {
  html.div([attribute.class("rounded-lg shadow p-3 bg-[var(--background)]")], [
    cover(venue.featured_image_url),
    html.div([attribute.class("font-semibold mt-2 truncate")], [
      element.text(name(venue)),
    ]),
    capacity(venue.capacity),
    tags(venue.tags),
  ])
}

fn cover(url: Option(String)) -> Element(msg) {
  case url {
    Some(src) if src != "" ->
      html.img([
        attribute.src(src),
        attribute.alt(""),
        attribute.class("w-full h-[120px] object-cover rounded"),
      ])
    _ -> element.none()
  }
}

fn capacity(value: Option(Int)) -> Element(msg) {
  case value {
    Some(seats) ->
      html.div([attribute.class("text-xs text-gray-500 mt-1")], [
        element.text("Capacity " <> int.to_string(seats)),
      ])
    _ -> element.none()
  }
}

fn tags(values: List(String)) -> Element(msg) {
  case values {
    [] -> element.none()
    _ ->
      html.div(
        [attribute.class("flex-row-item-center mt-2 gap-1 !flex-wrap")],
        list.map(values, fn(tag) {
          html.div(
            [
              attribute.class(
                "text-xs border rounded-full px-2 py-0.5 text-gray-500",
              ),
            ],
            [element.text(tag)],
          )
        }),
      )
  }
}

fn name(venue: VenueDetail) -> String {
  case venue.name {
    Some(value) if value != "" -> value
    _ -> venue.id
  }
}

fn group_name(group: GroupDetail) -> String {
  case group.nickname, group.name {
    Some(value), _ if value != "" -> value
    _, Some(value) if value != "" -> value
    _, _ -> group.id
  }
}
