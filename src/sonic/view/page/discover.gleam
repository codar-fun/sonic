//// The home page.
////
//// seastar-app serves Discover at `/`, not an events list — `(normal)/page.tsx`
//// delegates to `(normal)/discover/page.tsx` unless an `x-event-home` header
//// names a group, in which case that group's event home renders instead. The
//// per-domain group home is not built here yet; the default path is.
////
//// Section order and wrapper classes follow the original: featured cities,
//// popup cities, then communities, inside `page-width min-h-[100svh] pt-4
//// sm:pt-6 !pb-16`.

import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{type Discover, type Group, type PopupCity}
import sonic/view/event_time

pub fn view(data: Discover) -> Element(msg) {
  let featured = list.filter(data.popup_cities, is_featured)

  html.div([attribute.class("page-width min-h-[100svh] pt-4 sm:pt-6 !pb-16")], [
    section("Featured", list.map(featured, city_card)),
    section("Popup Cities", list.map(data.popup_cities, city_card)),
    // The original shows `communities` here — the pin-curated slice capped
    // server-side. It currently comes back empty, so `groups` stands in;
    // when the API starts populating it this switches over without the
    // section appearing or vanishing.
    section("Communities", list.map(visible_groups(data), group_card)),
  ])
}

fn visible_groups(data: Discover) -> List(Group) {
  case data.communities {
    [] -> data.groups
    communities -> communities
  }
}

fn is_featured(city: PopupCity) -> Bool {
  list.any(city.group_tags, fn(tag) { tag == "featured" || tag == ":featured" })
}

/// A titled block, omitted entirely when it has nothing to show — the original
/// guards each section with `list.length > 0` rather than rendering an empty
/// heading.
fn section(title: String, cards: List(Element(msg))) -> Element(msg) {
  case cards {
    [] -> element.none()
    _ ->
      html.div([attribute.class("mt-8")], [
        html.div([attribute.class("font-semibold text-lg mb-4")], [
          element.text(title),
        ]),
        html.div(
          [
            attribute.class(
              "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4",
            ),
          ],
          cards,
        ),
      ])
  }
}

fn city_card(city: PopupCity) -> Element(msg) {
  html.a(
    [
      attribute.href("/event/" <> handle(city)),
      attribute.class(
        "block rounded-lg overflow-hidden shadow hover:shadow-md transition-shadow bg-[var(--background)]",
      ),
    ],
    [
      cover(option_or(city.banner_image_url, city.image_url)),
      html.div([attribute.class("p-3")], [
        html.div([attribute.class("font-semibold truncate")], [
          element.text(display_name(city.nickname, city.name, city.id)),
        ]),
        meta_line(dates(city)),
        meta_line(city.location),
      ]),
    ],
  )
}

fn group_card(group: Group) -> Element(msg) {
  html.a(
    [
      attribute.href("/event/" <> group_handle(group)),
      attribute.class(
        "flex-row-item-center rounded-lg p-3 shadow hover:shadow-md transition-shadow bg-[var(--background)]",
      ),
    ],
    [
      avatar(option_or(group.image_url, group.logo_url)),
      html.div([attribute.class("ml-3 font-semibold truncate")], [
        element.text(display_name(group.nickname, group.name, group.id)),
      ]),
    ],
  )
}

fn cover(url: Option(String)) -> Element(msg) {
  case url {
    Some(src) if src != "" ->
      html.img([
        attribute.src(src),
        attribute.alt(""),
        attribute.class("w-full h-[140px] object-cover"),
      ])
    _ -> html.div([attribute.class("w-full h-[140px] bg-gray-100")], [])
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

fn meta_line(value: Option(String)) -> Element(msg) {
  case value {
    Some(text) if text != "" ->
      html.div([attribute.class("text-xs text-gray-500 mt-1 truncate")], [
        element.text(text),
      ])
    _ -> element.none()
  }
}

fn dates(city: PopupCity) -> Option(String) {
  case city.start_date, city.end_date {
    Some(start), Some(end) -> Some(event_time.range(start, end))
    Some(start), None -> Some(event_time.readable(start))
    _, _ -> None
  }
}

/// Groups are addressed by handle in URLs; the payload calls it `name`.
fn handle(city: PopupCity) -> String {
  case city.name {
    Some(name) if name != "" -> name
    _ -> city.id
  }
}

fn group_handle(group: Group) -> String {
  case group.name {
    Some(name) if name != "" -> name
    _ -> group.id
  }
}

/// The original prefers `nickname` for display and falls back to `name`.
fn display_name(
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

fn option_or(first: Option(String), second: Option(String)) -> Option(String) {
  case first {
    Some(value) if value != "" -> first
    _ -> second
  }
}
