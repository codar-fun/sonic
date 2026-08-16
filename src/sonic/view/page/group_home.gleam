//// A group's event home — what `/event/:grouphandle` serves.
////
//// Two columns that stack on mobile, with the event list first in source
//// order but second on wide screens (`order-2 md:order-1`) and the group
//// sidebar the other way round. Keeping the order attributes means the mobile
//// stacking order matches the original rather than merely looking similar on a
//// desktop screen.
////
//// The left column is Upcoming/Past tabs, a search row, then events grouped
//// under a date heading. The right column leads with the group identity and
//// its member count, then the schedule link, the banner, and the venue link.

import gleam/int

import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{type Event, type GroupDetail, type Page}
import sonic/view/event_card
import sonic/view/filter_panel
import sonic/view/image

pub fn view(
  group: GroupDetail,
  events: Page(Event),
  tab: String,
  signed_in: Bool,
) -> Element(msg) {
  html.div(
    [
      attribute.class(
        "page-width min-h-[100svh] sm:pt-8 pt-3 flex-col flex md:flex-row",
      ),
    ],
    [
      html.div([attribute.class("flex-1 md:max-w-[648px] order-2 md:order-1")], [
        tabs(group, tab),
        search_row(group),
        event_card.list(events),
      ]),
      html.div(
        [
          attribute.class(
            "md:w-[328px] ml-0 flex-col flex order-1 md:order-2 md:ml-6 mb-6",
          ),
        ],
        [sidebar(group, signed_in)],
      ),
    ],
  )
}

/// Upcoming / Past. Links rather than buttons, so the choice survives without
/// JavaScript; nothing reads the parameter yet, so neither is marked current.
/// Upcoming is the default, as upstream: someone arriving at a group wants to
/// know what is coming, not what they missed. The current tab is the dark one.
fn tabs(group: GroupDetail, current: String) -> Element(msg) {
  let base = "text-2xl font-semibold mr-4 cursor-pointer"
  let dim = base <> " text-gray-400"

  html.div([attribute.class("flex-row-item-center mb-4")], [
    html.a(
      [
        attribute.href(group_path(group) <> "?tab=upcoming"),
        attribute.class(case current {
          "past" -> dim
          _ -> base
        }),
      ],
      [element.text("Upcoming")],
    ),
    html.a(
      [
        attribute.href(group_path(group) <> "?tab=past"),
        attribute.class(case current {
          "past" -> base
          _ -> dim
        }),
      ],
      [element.text("Past")],
    ),
  ])
}

fn search_row(group: GroupDetail) -> Element(msg) {
  html.div([attribute.class("flex-row-item-center gap-2 mb-4")], [
    html.form(
      [
        attribute.method("get"),
        attribute.action("/search"),
        attribute.class("flex-1"),
      ],
      [
        html.input([
          attribute.type_("search"),
          attribute.name("keyword"),
          attribute.placeholder("Search..."),
          attribute.class(
            "w-full bg-[#f8f9f8] rounded-lg px-4 py-3 text-sm border-0",
          ),
        ]),
      ],
    ),
    icon_button(group_path(group) <> "/tracks", "uil-filter"),
    icon_button(group_path(group) <> "/schedule", "uil-calender"),
    icon_button(group_path(group) <> "/venues", "uil-rss"),
  ])
}

fn icon_button(href: String, glyph: String) -> Element(msg) {
  html.a(
    [
      attribute.href(href),
      attribute.class(
        "w-12 h-12 rounded-lg border border-gray-200 flex items-center justify-center",
      ),
    ],
    [html.i([attribute.class(glyph <> " text-xl")], [])],
  )
}

// --- sidebar ---------------------------------------------------------------

fn sidebar(group: GroupDetail, signed_in: Bool) -> Element(msg) {
  html.div([], [
    identity(group),
    action(group_path(group) <> "/schedule", "uil-calender", "Event Schedule", [
      "bg-[#fff5e5] text-[#f28c00]",
    ]),
    banner(group.banner_image_url),
    action(group_path(group) <> "/venues", "uil-home", "Venue List", [
      "bg-[#272928] text-white",
    ]),
    about(group.bio),
    participate(signed_in),
    filter_panel.view(),
  ])
}

fn identity(group: GroupDetail) -> Element(msg) {
  html.div([attribute.class("flex-row-item-center justify-between mb-3")], [
    html.div([attribute.class("flex-row-item-center min-w-0")], [
      image.avatar_or_default(
        first_present([group.image_url, group.logo_url]),
        group.id,
        32,
        "w-6 h-6 rounded-full",
      ),
      html.div([attribute.class("font-semibold ml-2 truncate")], [
        element.text(group_name(group)),
      ]),
    ]),
    // The member count, not a link: upstream has no /members page and this
    // one pointed at a route that only existed here.
    html.div([attribute.class("flex-row-item-center text-sm shrink-0")], [
      element.text(int.to_string(group.memberships_count) <> " Members"),
    ]),
  ])
}

fn action(
  href: String,
  glyph: String,
  label: String,
  classes: List(String),
) -> Element(msg) {
  html.a(
    [
      attribute.href(href),
      attribute.class(
        "flex-row-item-center justify-center rounded-lg py-3 mb-3 font-semibold "
        <> string.join(classes, " "),
      ),
    ],
    [
      html.i([attribute.class(glyph <> " mr-2")], []),
      element.text(label),
    ],
  )
}

/// The sign-in prompt, for signed-out visitors only. Upstream renders it as
/// `{!currProfile && <SignInPanel/>}`; without that guard it was telling
/// people who were already signed in to sign in.
fn participate(signed_in: Bool) -> Element(msg) {
  case signed_in {
    True -> element.none()
    False -> sign_in_panel()
  }
}

fn sign_in_panel() -> Element(msg) {
  html.div(
    [
      attribute.class(
        "rounded-lg p-4 mt-3 flex flex-col items-center border border-dashed border-gray-200",
      ),
    ],
    [
      html.div([attribute.class("text-sm mb-3")], [
        element.text("Sign in to participate in a fun event"),
      ]),
      html.a(
        [
          attribute.href("/signin"),
          attribute.class(
            "w-full text-center rounded-lg py-3 font-semibold bg-special text-special-foreground",
          ),
        ],
        [element.text("Sign In")],
      ),
    ],
  )
}

fn banner(url: Option(String)) -> Element(msg) {
  case url {
    Some(src) if src != "" ->
      html.img([
        attribute.src(src),
        attribute.alt(""),
        attribute.class("w-full h-auto rounded-lg mb-3"),
      ])
    _ -> element.none()
  }
}

fn about(value: Option(String)) -> Element(msg) {
  case value {
    Some(text) if text != "" ->
      html.div([attribute.class("text-sm whitespace-pre-wrap")], [
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
        attribute.class("w-6 h-6 rounded-full object-cover shrink-0"),
      ])
    _ ->
      html.div(
        [attribute.class("w-6 h-6 rounded-full bg-gray-100 shrink-0")],
        [],
      )
  }
}

// --- naming ----------------------------------------------------------------

fn group_path(group: GroupDetail) -> String {
  "/event/"
  <> case group.name {
    Some(name) if name != "" -> name
    _ -> group.id
  }
}

fn group_name(group: GroupDetail) -> String {
  profile_name(group.nickname, group.name, group.id)
}

fn profile_name(
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
