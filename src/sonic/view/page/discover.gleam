//// The home page.
////
//// seastar-app serves Discover at `/`, not an events list — `(normal)/page.tsx`
//// delegates to `(normal)/discover/page.tsx` unless an `x-event-home` header
//// names a group, in which case that group's event home renders instead. The
//// per-domain group home is not built here yet; the default path is.
////
//// Section order and classes are taken from the live page at app.sola.day:
//// a featured carousel, the create-a-group panel, the popup city grid, then
//// communities — all inside `page-width min-h-[100svh] pt-4 sm:pt-6 !pb-16`.

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute.{attribute}
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{type Discover, type Group, type PopupCity}
import sonic/view/community_list
import sonic/view/event_time

pub fn view(data: Discover) -> Element(msg) {
  let featured = list.filter(data.popup_cities, is_featured)

  html.div([attribute.class("page-width min-h-[100svh] pt-4 sm:pt-6 !pb-16")], [
    features(featured),
    create_group_panel(),
    popup_cities(data.popup_cities),
    communities(data),
  ])
}

/// The featured strip. Upstream drives it with embla, one slide visible at a
/// time; the slides themselves are plain links, so the markup is rendered in
/// full and the carousel behaviour is the part still missing rather than the
/// content.
fn features(cities: List(PopupCity)) -> Element(msg) {
  case cities {
    [] -> element.none()
    _ ->
      html.div(
        [
          attribute.class(
            "w-full mb-8 overflow-hidden rounded-lg border-gray-200 shadow",
          ),
        ],
        [
          html.div([attribute.class("relative")], [
            html.div([attribute.class("overflow-hidden")], [
              html.div(
                [attribute.class("flex -ml-4")],
                list.map(cities, feature_slide),
              ),
            ]),
          ]),
        ],
      )
  }
}

fn feature_slide(city: PopupCity) -> Element(msg) {
  html.a(
    [
      attribute.href("/event/" <> handle(city)),
      attribute.class("relative block h-[300px]"),
      attribute.styles([#("flex", "0 0 100%"), #("padding-left", "1rem")]),
    ],
    [
      // An <img>, not a background: upstream serves these through an image CDN
      // and sets fetchpriority/eager so the banner is not a late paint.
      case first_present([city.banner_image_url, city.image_url]) {
        Some(src) ->
          html.img([
            attribute.src(src),
            attribute.alt(option_text(city.name)),
            attribute.class("w-full h-full object-cover"),
            attribute("fetchpriority", "high"),
            attribute("loading", "eager"),
            attribute("decoding", "async"),
          ])
        None -> html.div([attribute.class("w-full h-full bg-gray-100")], [])
      },
      // Upstream renders this caption and hides it (`hidden`), so the banner
      // shows artwork alone. Kept, with the class, rather than dropped — the
      // markup is theirs and a later variant may reveal it.
      html.div(
        [
          attribute.class(
            "hidden absolute bottom-0 left-0 right-0 sm:pt-[140px] pt-[100px] px-6 h-[250px]",
          ),
        ],
        [
          html.div(
            [attribute.class("flex sm:flex-row flex-col sm:gap-4 mb-2")],
            [
              html.div([attribute.class("webkit-box-clamp-1 text-sm")], [
                element.text(display_name(city.nickname, city.name, city.id)),
              ]),
            ],
          ),
          meta_line(dates(city)),
          meta_line(city.location),
        ],
      ),
    ],
  )
}

/// The create-a-group panel. Upstream gates the button behind a sign-in check
/// in JavaScript; here it is a link to the same destination, so it works
/// without a runtime and an anonymous visitor lands on sign-in anyway.
fn create_group_panel() -> Element(msg) {
  html.div(
    [
      attribute.class(
        "bg-cover h-auto py-6 px-4 sm:py-0 sm:h-[230px] w-full rounded-lg mb-6 flex flex-col justify-center items-center",
      ),
      attribute.styles([
        #("background", "url(/static/images/popup_city_bg.jpg)"),
        #("background-size", "100% 100%"),
      ]),
    ],
    [
      html.div(
        [
          attribute.class(
            "font-semibold sm:text-2xl text-base mb-4 text-center",
          ),
        ],
        [element.text("Want to create your own Group?")],
      ),
      html.div(
        [
          attribute.class(
            "sm:max-w-[400px] max-w-[300px] text-center mb-4 sm:text-base text-xs",
          ),
        ],
        [
          element.text(
            "Start now and let more people freely organize and participate in your exciting events!",
          ),
        ],
      ),
      html.a(
        [
          attribute.href("/group/create"),
          attribute.class(
            "bg-[#EFFFF9] text-sm sm:text-base rounded-lg px-4 py-2",
          ),
        ],
        [element.text("Create Now")],
      ),
    ],
  )
}

fn popup_cities(cities: List(PopupCity)) -> Element(msg) {
  case cities {
    [] -> element.none()
    _ ->
      html.div([], [
        // h2 with the title and the see-all link, exactly as upstream: the
        // heading element is a flex row that puts them at opposite ends.
        html.h2(
          [
            attribute.class(
              "text-2xl font-semibold mb-3 md:flex-row flex items-center justify-between flex-col",
            ),
          ],
          [
            html.div([], [element.text("Pop-up Cities")]),
            html.a(
              [
                attribute.href("/popup-city"),
                attribute.class("flex-row-item-center text-sm"),
              ],
              [
                html.span([], [element.text("See all Pop-up Cities events")]),
                html.i([attribute.class("uil-arrow-right text-2xl ml-1")], []),
              ],
            ),
          ],
        ),
        filters(),
        html.div(
          [
            attribute.class(
              "grid md:grid-cols-4 sm:grid-cols-3 grid-cols-2 gap-2",
            ),
          ],
          list.map(cities, city_card),
        ),
      ])
  }
}

/// The status filters. Upstream re-queries on click; these are links carrying
/// the choice in the query string, so they work without JavaScript. Nothing
/// reads the parameter yet, which is why none is marked active.
fn filters() -> Element(msg) {
  let base =
    "font-semibold inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-lg ring-offset-background transition-colors border border-foreground bg-background hover:bg-accent hover:opacity-80 h-9 px-3 text-xs"

  html.div(
    [attribute.class("flex gap-2 mb-4")],
    list.map(["All", "Ongoing", "Upcoming", "Past"], fn(label) {
      html.a(
        [
          attribute.href("/?status=" <> string.lowercase(label)),
          attribute.class(base),
        ],
        [element.text(label)],
      )
    }),
  )
}

fn city_card(city: PopupCity) -> Element(msg) {
  html.a(
    [
      attribute.href("/event/" <> handle(city)),
      attribute.class(
        "rounded shadow p-3 duration-200 hover:translate-y-[-6px]",
      ),
    ],
    [
      html.div([attribute.class("rounded aspect-[3/2] mb-3 overflow-hidden")], [
        cover(first_present([city.image_url, city.banner_image_url])),
      ]),
      html.div(
        [
          attribute.class(
            "webkit-box-clamp-2 text-lg font-semibold leading-5 h-10 mb-4",
          ),
        ],
        [element.text(display_name(city.nickname, city.name, city.id))],
      ),
      html.div([attribute.class("webkit-box-clamp-1 sm:text-sm text-xs")], [
        element.text(option_text(dates(city))),
      ]),
    ],
  )
}

fn communities(data: Discover) -> Element(msg) {
  case visible_groups(data) {
    [] -> element.none()
    groups ->
      html.div([attribute.class("mt-8")], [
        html.div(
          [
            attribute.class(
              "text-2xl font-semibold mb-3 md:flex-row flex items-center justify-between flex-col",
            ),
          ],
          [html.div([], [element.text("Communities")])],
        ),
        // The same grid /communities renders, so the two cannot drift.
        community_list.from_groups(groups),
      ])
  }
}

/// `communities` comes back empty from the live endpoint today, so `groups`
/// stands in. When the API starts populating it this switches over without the
/// section appearing or vanishing.
fn visible_groups(data: Discover) -> List(Group) {
  case data.communities {
    [] -> data.groups
    communities -> communities
  }
}

fn is_featured(city: PopupCity) -> Bool {
  list.any(city.group_tags, fn(tag) { tag == "featured" || tag == ":featured" })
}

fn cover(url: Option(String)) -> Element(msg) {
  case url {
    Some(src) if src != "" ->
      html.img([
        attribute.src(src),
        attribute.alt(""),
        attribute.class("object-cover w-full h-full rounded"),
      ])
    _ -> html.div([attribute.class("w-full h-full bg-gray-100 rounded")], [])
  }
}

fn meta_line(value: Option(String)) -> Element(msg) {
  case value {
    Some(text) if text != "" ->
      html.div([attribute.class("webkit-box-clamp-1 text-sm")], [
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

fn handle(city: PopupCity) -> String {
  case city.name {
    Some(name) if name != "" -> name
    _ -> city.id
  }
}

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

fn first_present(values: List(Option(String))) -> Option(String) {
  case values {
    [Some(value), ..] if value != "" -> Some(value)
    [_, ..rest] -> first_present(rest)
    [] -> None
  }
}

fn option_text(value: Option(String)) -> String {
  case value {
    Some(text) -> text
    None -> ""
  }
}
