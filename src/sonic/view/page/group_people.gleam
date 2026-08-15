//// A group's members and its tracks.
////
//// Two small pages in one module because they are the same shape — a group
//// heading over a list — and splitting them would duplicate the heading and
//// the name-resolution rules.

import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{
  type GroupDetail, type Membership, type Page, type Profile, type TrackDetail,
}
import sonic/view/event_time

pub fn members(group: GroupDetail, people: Page(Membership)) -> Element(msg) {
  page(group, "Members", case people.data {
    [] -> empty("No members yet.")
    rows ->
      html.div(
        [attribute.class("grid grid-cols-2 sm:grid-cols-3 gap-3")],
        list.map(rows, member_card),
      )
  })
}

pub fn tracks(group: GroupDetail, items: Page(TrackDetail)) -> Element(msg) {
  page(group, "Tracks", case items.data {
    [] -> empty("No tracks yet.")
    rows -> html.div([], list.map(rows, track_row))
  })
}

fn page(group: GroupDetail, title: String, body: Element(msg)) -> Element(msg) {
  html.div([attribute.class("page-width min-h-[100svh] !pt-4 !pb-12")], [
    html.div([attribute.class("text-lg font-semibold mb-4")], [
      element.text(group_name(group) <> " · " <> title),
    ]),
    body,
  ])
}

fn empty(message: String) -> Element(msg) {
  html.div([attribute.class("text-center text-gray-400 py-10")], [
    element.text(message),
  ])
}

fn member_card(item: Membership) -> Element(msg) {
  html.a(
    [
      attribute.href("/profile/" <> profile_handle(item.user)),
      attribute.class(
        "flex-row-item-center gap-2 rounded-lg p-2 shadow bg-[var(--background)]",
      ),
    ],
    [
      avatar(profile_image(item.user)),
      html.div([attribute.class("min-w-0")], [
        html.div([attribute.class("text-sm truncate")], [
          element.text(profile_name(item.user)),
        ]),
        role(item.role),
      ]),
    ],
  )
}

/// Roles other than plain membership are worth showing — an owner and a member
/// look identical otherwise.
fn role(value: Option(String)) -> Element(msg) {
  case value {
    Some(name) if name != "" && name != "member" ->
      html.div([attribute.class("text-xs text-gray-500")], [
        element.text(name),
      ])
    _ -> element.none()
  }
}

fn track_row(track: TrackDetail) -> Element(msg) {
  html.div(
    [
      attribute.class("p-3 rounded-lg mb-2 shadow bg-[var(--background)]"),
    ],
    [
      html.div([attribute.class("font-semibold")], [
        element.text(track_title(track)),
      ]),
      dates(track),
      description(track.description),
    ],
  )
}

fn dates(track: TrackDetail) -> Element(msg) {
  let range = case track.start_date, track.end_date {
    Some(start), Some(end) -> Some(event_time.range(start, end))
    Some(start), None -> Some(event_time.readable(start))
    _, _ -> None
  }
  case range {
    Some(text) ->
      html.div([attribute.class("text-xs text-gray-500 mt-1")], [
        element.text(text),
      ])
    None -> element.none()
  }
}

fn description(value: Option(String)) -> Element(msg) {
  case value {
    Some(text) if text != "" ->
      html.div([attribute.class("text-sm mt-2 whitespace-pre-wrap")], [
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
        attribute.class("w-8 h-8 rounded-full object-cover shrink-0"),
      ])
    _ ->
      html.div(
        [attribute.class("w-8 h-8 rounded-full bg-gray-100 shrink-0")],
        [],
      )
  }
}

fn profile_image(who: Option(Profile)) -> Option(String) {
  case who {
    Some(p) -> p.image_url
    None -> None
  }
}

fn profile_handle(who: Option(Profile)) -> String {
  case who {
    Some(p) ->
      case p.name {
        Some(name) if name != "" -> name
        _ -> p.id
      }
    None -> ""
  }
}

fn profile_name(who: Option(Profile)) -> String {
  case who {
    Some(p) ->
      case p.nickname, p.name {
        Some(value), _ if value != "" -> value
        _, Some(value) if value != "" -> value
        _, _ -> p.id
      }
    None -> "someone"
  }
}

fn track_title(track: TrackDetail) -> String {
  case track.title {
    Some(value) if value != "" -> value
    _ -> track.id
  }
}

fn group_name(group: GroupDetail) -> String {
  case group.nickname, group.name {
    Some(value), _ if value != "" -> value
    _, Some(value) if value != "" -> value
    _, _ -> group.id
  }
}
