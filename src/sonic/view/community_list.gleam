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
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{type GroupDetail}

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
  html.a(
    [
      attribute.href("/event/" <> handle(group)),
      attribute.class(
        "h-[200px] rounded shadow p-3 duration-200 hover:translate-y-[-6px] relative",
      ),
    ],
    [
      avatar(first_present([group.image_url, group.logo_url])),
      html.div(
        [
          attribute.class(
            "webkit-box-clamp-2 text-lg font-semibold leading-5 h-10 mb-4 mt-2",
          ),
        ],
        [element.text(display_name(group))],
      ),
      html.div([attribute.class("text-sm")], [
        html.strong([attribute.class("mr-1")], [
          element.text(int.to_string(group.memberships_count)),
        ]),
        element.text("Members"),
      ]),
    ],
  )
}

fn avatar(url: Option(String)) -> Element(msg) {
  case url {
    Some(src) if src != "" ->
      html.img([
        attribute.src(src),
        attribute.alt(""),
        attribute.width(64),
        attribute.height(64),
        attribute.class("object-cover rounded-full w-16 h-16"),
      ])
    _ -> html.div([attribute.class("rounded-full w-16 h-16 bg-gray-100")], [])
  }
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
