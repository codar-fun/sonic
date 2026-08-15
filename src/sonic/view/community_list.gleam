//// The community card grid.
////
//// Ported from `components/CommunityList.tsx`, which upstream shares between
//// the home page section and `/communities` precisely so the two cannot drift
//// — they had already been copy-pasted apart once. Same reason it lives here
//// rather than inside either page.
////
//// Cards link to the group's event home, not a profile page: what someone
//// wants from a community is what it has on.
////
//// Rendered in the order the API returned. The list is ordered server-side and
//// re-sorting here would only be a second, competing opinion.

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{type Group, type GroupDetail}
import sonic/view/image

/// The discover payload carries a lighter `Group` shape than /communities
/// does; this renders it through the same card so the two grids stay one
/// definition rather than two that look alike today.
pub fn from_groups(groups: List(Group)) -> Element(msg) {
  case groups {
    [] -> element.none()
    _ ->
      html.div(
        [
          attribute.class(
            "grid md:grid-cols-4 sm:grid-cols-3 grid-cols-2 gap-2",
          ),
        ],
        list.map(groups, group_card),
      )
  }
}

fn group_card(group: Group) -> Element(msg) {
  card_markup(
    id: group.id,
    handle: case group.name {
      Some(name) if name != "" -> name
      _ -> group.id
    },
    name: case group.nickname, group.name {
      Some(value), _ if value != "" -> value
      _, Some(value) if value != "" -> value
      _, _ -> group.id
    },
    image: first_present([group.image_url, group.logo_url]),
    members: None,
    events: None,
  )
}

pub fn view(communities: List(GroupDetail)) -> Element(msg) {
  case communities {
    [] -> element.none()
    _ ->
      html.div(
        [
          attribute.class(
            "grid md:grid-cols-4 sm:grid-cols-3 grid-cols-2 gap-2",
          ),
        ],
        list.map(communities, card),
      )
  }
}

fn card(group: GroupDetail) -> Element(msg) {
  card_markup(
    id: group.id,
    handle: handle(group),
    name: display_name(group),
    image: first_present([group.image_url, group.logo_url]),
    members: Some(group.memberships_count),
    events: Some(group.events_count),
  )
}

fn card_markup(
  id id: String,
  handle handle: String,
  name name: String,
  image image: Option(String),
  members members: Option(Int),
  events events: Option(Int),
) -> Element(msg) {
  html.a(
    [
      attribute.href("/event/" <> handle),
      attribute.class(
        "h-[200px] rounded shadow p-3 duration-200 hover:translate-y-[-6px] relative",
      ),
    ],
    [
      avatar(image, id),
      html.div(
        [
          attribute.class(
            "webkit-box-clamp-2 text-lg font-semibold leading-5 h-10 mb-4 mt-2",
          ),
        ],
        [element.text(name)],
      ),
      count_line(members, "Members"),
      count_line(events, "Events"),
    ],
  )
}

fn count_line(value: Option(Int), label: String) -> Element(msg) {
  case value {
    Some(count) ->
      html.div([attribute.class("text-sm")], [
        html.strong([attribute.class("mr-1")], [
          element.text(int.to_string(count)),
        ]),
        element.text(label),
      ])
    None -> element.none()
  }
}

/// Upstream falls back to one of six shipped avatars rather than an empty
/// box, picked deterministically so a group keeps the same one between renders.
fn avatar(url: Option(String), id: String) -> Element(msg) {
  let src = case url {
    Some(value) if value != "" -> value
    _ -> "/static/images/default_avatar/avatar_" <> default_index(id) <> ".png"
  }

  html.img([
    attribute.src(image.avatar(src)),
    attribute.alt(""),
    attribute.width(64),
    attribute.height(64),
    attribute.styles([#("width", "64px"), #("height", "64px")]),
    attribute.class("rounded-full object-cover"),
    ..image.lazy()
  ])
}

/// Stable per group: the same id always maps to the same avatar, so a card
/// does not change face between page loads.
fn default_index(id: String) -> String {
  let sum =
    id
    |> string.to_utf_codepoints
    |> list.fold(0, fn(acc, point) { acc + string.utf_codepoint_to_int(point) })
  int.to_string(sum % 6)
}

fn handle(group: GroupDetail) -> String {
  case group.name {
    Some(name) if name != "" -> name
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

fn first_present(values: List(Option(String))) -> Option(String) {
  case values {
    [Some(value), ..] if value != "" -> Some(value)
    [_, ..rest] -> first_present(rest)
    [] -> None
  }
}
