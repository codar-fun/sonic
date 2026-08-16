//// A public profile.
////
//// Three tabs — Events, Groups, Badges — with the Events tab carrying four
//// lists of its own. Upstream switches these client-side; here they are links
//// carrying the choice in the query string, so every view has its own URL and
//// the page works with no runtime.
////
//// The header is a fixed banner with the avatar overlapping its lower edge,
//// which is why the avatar block has a negative top margin rather than the
//// two being laid out in flow.

import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute.{attribute}
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{
  type Badge, type Event, type Membership, type UserProfile,
}
import sonic/view/event_card
import sonic/view/image

/// What the page is showing. `Events` carries which of its four lists.
pub type Tab {
  Events(list: String)
  Groups
  Badges
}

pub fn view(
  user: UserProfile,
  tab: Tab,
  events: List(Event),
  groups: List(Membership),
  badges: List(Badge),
) -> Element(msg) {
  html.div(
    [attribute.class("page-width min-h-[100svh] !pt-4 !pb-12 sm:flex-row flex flex-col")],
    [
      header(user),
      html.div([attribute.class("flex-1 sm:ml-6 px-3 w-full min-w-0")], [
        tab_bar(user, tab),
        case tab {
          Events(which) ->
            html.div([], [
              event_lists(user, which),
              event_results(events),
            ])
          Groups -> group_results(groups)
          Badges -> badge_results(badges)
        },
      ]),
    ],
  )
}

fn header(user: UserProfile) -> Element(msg) {
  html.div([attribute.class("bg-white w-full sm:w-[375px] mb-3 relative")], [
    html.img([
      attribute.src("/static/images/profile_bg.png"),
      attribute.alt(""),
      attribute.class("w-full h-[140px]"),
    ]),
    html.div([attribute.class("absolute right-3 top-3")], [
      html.div([attribute.class("flex-row-item-center")], [
        html.div([attribute.class("text-xs")], [element.text(handle(user))]),
        html.i([attribute.class("uil-copy-alt ml-1")], []),
      ]),
    ]),
    // Pulled up over the banner's lower edge.
    html.div([attribute.class("px-3 mt-[-40px]")], [
      image.avatar_or_default(
        user.image_url,
        user.id,
        120,
        "w-[60px] h-[60px] rounded-full",
      ),
      html.div([attribute.class("flex-row-item-center my-2")], [
        html.div([attribute.class("font-semibold text-5")], [
          element.text(display_name(user)),
        ]),
      ]),
      bio(user.bio),
    ]),
  ])
}

fn tab_bar(user: UserProfile, current: Tab) -> Element(msg) {
  let base = "/profile/" <> handle(user)

  html.div(
    [
      attribute.class("tab-titles flex-row-item-center overflow-auto"),
      attribute("role", "tablist"),
    ],
    [
      tab_link(base, "Events", is_events(current)),
      tab_link(base <> "?tab=groups", "Groups", current == Groups),
      tab_link(base <> "?tab=badges", "Badges", current == Badges),
    ],
  )
}

fn is_events(tab: Tab) -> Bool {
  case tab {
    Events(_) -> True
    _ -> False
  }
}

fn tab_link(href: String, label: String, selected: Bool) -> Element(msg) {
  html.a(
    [
      attribute.href(href),
      attribute("role", "tab"),
      attribute("aria-selected", case selected {
        True -> "true"
        False -> "false"
      }),
      attribute.class(
        "font-semibold inline-flex items-center justify-center whitespace-nowrap rounded-lg transition-colors h-11 px-4 py-2 mr-3 shrink-0 "
        <> case selected {
          True -> "bg-foreground text-white hover:opacity-80"
          False -> "hover:bg-secondary hover:text-accent-foreground"
        },
      ),
    ],
    [html.span([attribute.class("font-normal")], [element.text(label)])],
  )
}

/// The Events tab's own four lists.
fn event_lists(user: UserProfile, current: String) -> Element(msg) {
  let base = "/profile/" <> handle(user) <> "?list="

  html.div(
    [attribute.class("flex flex-row-item-center gap-2 my-3 overflow-auto")],
    list.map(
      [
        #("attending", "Attending"),
        #("hosting", "Hosting"),
        #("co-hosting", "Co-hosting"),
        #("starred", "Starred"),
      ],
      fn(entry) {
        let #(key, label) = entry
        html.a(
          [
            attribute.href(base <> key),
            attribute.class(
              "font-semibold inline-flex items-center justify-center whitespace-nowrap rounded-lg transition-colors h-9 px-3 shrink-0 "
              <> case key == current {
                True -> "border border-foreground bg-background"
                False -> "hover:bg-secondary"
              },
            ),
          ],
          [
            html.span([attribute.class("font-normal text-sm")], [
              element.text(label),
            ]),
          ],
        )
      },
    ),
  )
}

fn event_results(events: List(Event)) -> Element(msg) {
  case events {
    [] -> empty("No events here yet.")
    // Ordered as upstream does: happening now, then coming, then finished
    // most-recent-first. Unsorted, a profile opened on its oldest event.
    rows ->
      html.div([], list.map(event_card.sort_by_time(rows), event_card.card))
  }
}

fn group_results(groups: List(Membership)) -> Element(msg) {
  case groups {
    [] -> empty("Not a member of any group yet.")
    rows ->
      html.div(
        [attribute.class("grid grid-cols-1 sm:grid-cols-2 gap-3 mt-3")],
        list.map(rows, fn(membership) {
          case membership.group {
            Some(group) ->
              html.a(
                [
                  attribute.href("/event/" <> group_handle(group)),
                  attribute.class(
                    "flex-row-item-center p-3 rounded-lg shadow hover:shadow-md transition-shadow",
                  ),
                ],
                [
                  image.avatar_or_default(
                    group.image_url,
                    group.id,
                    96,
                    "w-12 h-12 rounded-full mr-3",
                  ),
                  html.div([attribute.class("min-w-0")], [
                    html.div([attribute.class("font-semibold truncate")], [
                      element.text(group_name(group)),
                    ]),
                    html.div([attribute.class("text-xs text-gray-400")], [
                      element.text(option_text(membership.role)),
                    ]),
                  ]),
                ],
              )
            None -> element.none()
          }
        }),
      )
  }
}

fn badge_results(badges: List(Badge)) -> Element(msg) {
  case badges {
    [] -> empty("No badges yet.")
    rows ->
      html.div(
        [attribute.class("grid grid-cols-3 sm:grid-cols-4 gap-3 mt-3")],
        list.map(rows, fn(badge) {
          html.a(
            [
              attribute.href("/badge/" <> badge.id),
              attribute.class("flex flex-col items-center"),
            ],
            [
              case badge.image_url {
                Some(src) if src != "" ->
                  image.square_img(src, 160, "", "w-20 h-20 rounded-full")
                _ ->
                  html.div(
                    [attribute.class("w-20 h-20 rounded-full bg-gray-100")],
                    [],
                  )
              },
              html.div(
                [attribute.class("text-xs text-center mt-2 line-clamp-2")],
                [element.text(option_text(badge.title))],
              ),
            ],
          )
        }),
      )
  }
}

fn empty(message: String) -> Element(msg) {
  html.div([attribute.class("text-center text-gray-400 py-10")], [
    element.text(message),
  ])
}

fn bio(text: Option(String)) -> Element(msg) {
  case text {
    Some(value) if value != "" ->
      html.div([attribute.class("text-sm mb-3 whitespace-pre-line")], [
        element.text(value),
      ])
    _ -> element.none()
  }
}

fn handle(user: UserProfile) -> String {
  case user.name {
    Some(name) if name != "" -> name
    _ -> user.id
  }
}

fn display_name(user: UserProfile) -> String {
  case user.nickname, user.name {
    Some(value), _ if value != "" -> value
    _, Some(value) if value != "" -> value
    _, _ -> user.id
  }
}

fn group_handle(group: types.GroupDetail) -> String {
  case group.name {
    Some(name) if name != "" -> name
    _ -> group.id
  }
}

fn group_name(group: types.GroupDetail) -> String {
  case group.nickname, group.name {
    Some(value), _ if value != "" -> value
    _, Some(value) if value != "" -> value
    _, _ -> group.id
  }
}

fn option_text(value: Option(String)) -> String {
  case value {
    Some(text) -> text
    None -> ""
  }
}
