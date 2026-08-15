//// A single event.
////
//// Follows app.sola.day: a group breadcrumb with a Share action, the title,
//// a status/tag row, the host, then the date block — with the cover and the
//// participate call-to-action in a right column that drops below on mobile.
////
//// The Content/Participants tabs and the comment box are rendered because
//// they are part of the page's shape; posting a comment is a write path and
//// is not built, so the box is disabled with the same wording upstream shows
//// a signed-out visitor rather than a control that silently does nothing.

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute.{attribute}
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{type Event}
import sonic/view/badge
import sonic/view/event_time
import sonic/view/image

pub fn view(event: Event) -> Element(msg) {
  html.div([attribute.class("page-width !pt-4 !pb-12")], [
    top_bar(event),
    html.div([attribute.class("flex flex-col sm:flex-row")], [
      html.div(
        [
          attribute.class(
            "min-w-[324px] sm:max-w-[324px] mb-8 order-1 sm:order-2 sm:mb-0",
          ),
        ],
        [cover(event.cover), participate()],
      ),
      html.div([attribute.class("flex-1 min-w-0 sm:mr-9 order-2 sm:order-1")], [
        html.div([attribute.class("text-4xl font-semibold w-full")], [
          element.text(event.title),
        ]),
        tag_row(event),
        host_row(event),
        date_row(event),
        location_block(event),
        tabs(event),
        body(event),
        comments(),
      ]),
    ]),
  ])
}

fn top_bar(event: Event) -> Element(msg) {
  html.div(
    [attribute.class("flex flex-row items-center justify-between sm:mb-8 mb-4")],
    [
      case event.group {
        Some(group) ->
          html.a(
            [
              attribute.href("/event/" <> option_text(group.name)),
              attribute.class("flex-row-item-center"),
            ],
            [
              image.avatar_or_default(
                group.image_url,
                group.id,
                "w-6 h-6 rounded-full",
              ),
              html.div([attribute.class("font-semibold ml-2")], [
                element.text(name_of(group.nickname, group.name, group.id)),
              ]),
            ],
          )
        None -> html.div([], [])
      },
      html.a(
        [
          attribute.href("/event/detail/" <> event.id),
          attribute.class(
            "flex-row-item-center bg-[#f1f1f1] rounded-lg px-3 py-2 text-sm font-semibold",
          ),
        ],
        [
          html.i([attribute.class("uil-external-link-alt mr-1")], []),
          element.text("Share"),
        ],
      ),
    ],
  )
}

/// Status badge and tags on one line. Upstream marks each tag with a coloured
/// dot; the colour is derived from the tag there, so a fixed palette is used
/// here rather than inventing a per-tag colour that would not match anyway.
fn tag_row(event: Event) -> Element(msg) {
  let tags =
    list.map(event.tags, fn(tag) {
      html.div([attribute.class("flex-row-item-center mr-3 text-sm")], [
        html.span(
          [attribute.class("w-2 h-2 rounded-full bg-[#c863ff] mr-1 shrink-0")],
          [],
        ),
        element.text(tag),
      ])
    })

  case has_status(event), tags {
    False, [] -> element.none()
    _, _ ->
      html.div(
        [
          attribute.class(
            "flex-row-item-center my-3 gap-1 overflow-auto !flex-wrap",
          ),
        ],
        [status_badge(event), ..tags],
      )
  }
}

fn has_status(event: Event) -> Bool {
  case event.status, event.visibility {
    "cancelled", _ | "pending", _ -> True
    _, "private" -> True
    _, _ -> False
  }
}

fn status_badge(event: Event) -> Element(msg) {
  case event.status, event.visibility {
    "cancelled", _ -> badge.view(badge.Cancel, "Cancelled")
    "pending", _ -> badge.view(badge.Pending, "Pending")
    _, "private" -> badge.view(badge.Private, "Private")
    _, _ -> element.none()
  }
}

/// The host, then every co-host from `event_roles`, on one scrollable row —
/// upstream shows all of them, not just the owner.
fn host_row(event: Event) -> Element(msg) {
  let owner = case event.owner {
    Some(o) -> [
      person(o.image_url, o.id, name_of(o.nickname, o.name, o.id), "Host"),
    ]
    None -> []
  }

  let co_hosts =
    list.map(event.roles, fn(role) {
      person(
        role.image_url,
        option_text(role.display_name),
        option_text(role.display_name),
        label_for(role.role),
      )
    })

  case list.append(owner, co_hosts) {
    [] -> element.none()
    people ->
      html.div(
        [
          attribute.class("flex-row-item-center py-4 gap-5 overflow-auto"),
          attribute.styles([
            #("border-top", "1px solid #f1f1f1"),
            #("border-bottom", "1px solid #f1f1f1"),
          ]),
        ],
        people,
      )
  }
}

fn person(
  picture: Option(String),
  id: String,
  name: String,
  role: String,
) -> Element(msg) {
  html.div([attribute.class("flex-row-item-center shrink-0")], [
    image.avatar_or_default(picture, id, "w-10 h-10 rounded-full"),
    html.div([attribute.class("ml-2")], [
      html.div([attribute.class("font-semibold")], [element.text(name)]),
      html.div([attribute.class("text-sm text-gray-400")], [element.text(role)]),
    ]),
  ])
}

/// `co_host` reads as machinery; upstream shows "Co-Host".
fn label_for(role: Option(String)) -> String {
  case role {
    Some("co_host") -> "Co-Host"
    Some("speaker") -> "Speaker"
    Some(other) if other != "" -> other
    _ -> "Host"
  }
}

fn date_row(event: Event) -> Element(msg) {
  html.div([attribute.class("flex-row-item-center py-4")], [
    html.div(
      [
        attribute.class(
          "w-10 h-10 rounded-lg bg-[#f8f9f8] flex items-center justify-center shrink-0",
        ),
      ],
      [html.i([attribute.class("uil-calender text-lg")], [])],
    ),
    html.div([attribute.class("ml-3")], [
      html.div([attribute.class("font-semibold")], [
        element.text(event_time.in_zone_date(event.start_time, event.timezone)),
      ]),
      html.div([attribute.class("text-gray-400")], [
        element.text(event_time.in_zone_range(
          event.start_time,
          event.end_time,
          event.timezone,
        )),
      ]),
    ]),
  ])
}

/// Venue name over its address, with the map links upstream offers.
fn location_block(event: Event) -> Element(msg) {
  let name = case event.venue, event.place {
    Some(v), _ -> first_present([v.title, v.location])
    None, Some(p) -> p.title
    None, None -> None
  }
  let address = case event.place {
    Some(p) -> first_present([p.address, p.formatted_address, p.location])
    None -> None
  }

  case name, address {
    None, None -> element.none()
    _, _ ->
      html.div([attribute.class("flex-row-item-center py-4")], [
        html.div(
          [
            attribute.class(
              "w-10 h-10 rounded-lg bg-[#f8f9f8] flex items-center justify-center shrink-0",
            ),
          ],
          [html.i([attribute.class("uil-location-point text-lg")], [])],
        ),
        html.div([attribute.class("ml-3 min-w-0")], [
          case name {
            Some(text) ->
              html.div([attribute.class("font-semibold")], [element.text(text)])
            None -> element.none()
          },
          case address {
            Some(text) ->
              html.div([attribute.class("text-gray-400")], [element.text(text)])
            None -> element.none()
          },
          case address {
            Some(text) ->
              html.a(
                [
                  attribute.href(
                    "https://www.google.com/maps/search/?api=1&query=" <> text,
                  ),
                  attribute.class("text-sm text-[#6cd7b2] mr-3"),
                  attribute("target", "_blank"),
                  attribute("rel", "noopener noreferrer"),
                ],
                [element.text("View map")],
              )
            None -> element.none()
          },
        ]),
      ])
  }
}

/// Content / Participants(n). Both render the same panel for now — the
/// participants list is a separate call that is not wired up, and a tab that
/// silently shows the wrong thing would be worse than one that is honest.
fn tabs(event: Event) -> Element(msg) {
  html.div(
    [
      attribute.class("flex-row-item-center justify-around my-6"),
      attribute.styles([#("border-bottom", "1px solid #f1f1f1")]),
    ],
    [
      html.div(
        [attribute.class("font-semibold pb-2 border-b-2 border-[#7ff7ce]")],
        [element.text("Content")],
      ),
      html.div([attribute.class("font-semibold pb-2 text-gray-400")], [
        element.text(
          "Participants(" <> int.to_string(event.participant_count) <> ")",
        ),
      ]),
    ],
  )
}

/// `content` holds the description; `notes` is a different field that is
/// usually empty. Reading only `notes` left every event body blank.
fn body(event: Event) -> Element(msg) {
  case first_present([event.content, event.notes]) {
    Some(text) if text != "" ->
      // Rendered as HTML, as upstream does. markdown-it escapes raw HTML in
      // the source (html: false), so a description cannot inject markup —
      // these bodies are user-supplied.
      //
      // break-words and min-w-0 on the column because a single unbroken URL in
      // a description is wide enough to push the layout past the viewport and
      // squash the sidebar off screen.
      element.unsafe_raw_html(
        "",
        "div",
        [attribute.class("markdown break-words overflow-hidden")],
        render_markdown(text),
      )
    _ -> element.none()
  }
}

fn comments() -> Element(msg) {
  html.div([attribute.class("mt-6")], [
    html.div([attribute.class("font-semibold mb-3")], [
      element.text("Comments"),
    ]),
    html.div([attribute.class("bg-[#f8f9f8] rounded-lg p-3")], [
      html.textarea(
        [
          attribute.class("w-full bg-transparent outline-none text-sm"),
          attribute.placeholder("Input comment"),
          attribute("rows", "3"),
          attribute.disabled(True),
        ],
        "",
      ),
      html.div([attribute.class("flex justify-end")], [
        html.a(
          [
            attribute.href("/signin"),
            attribute.class(
              "bg-[#272928] text-white rounded-lg px-3 py-2 text-sm font-semibold",
            ),
          ],
          [element.text("Sign in to send a comment")],
        ),
      ]),
    ]),
  ])
}

fn cover(url: Option(String)) -> Element(msg) {
  case url {
    Some(src) if src != "" ->
      html.div(
        [attribute.class("w-[324px] h-[324px] overflow-hidden mx-auto")],
        [
          html.img([
            attribute.src(src),
            attribute.alt(""),
            attribute.class("w-full h-full object-cover rounded-lg"),
          ]),
        ],
      )
    _ ->
      html.div(
        [
          attribute.class(
            "w-[324px] h-[324px] overflow-hidden mx-auto rounded-lg bg-gray-100",
          ),
        ],
        [],
      )
  }
}

/// The participate panel. Joining is a write path and is not built, so this
/// sends people to sign-in exactly as upstream does for a signed-out visitor.
fn participate() -> Element(msg) {
  html.div(
    [
      attribute.class(
        "rounded-lg p-4 mt-4 flex flex-col items-center border border-dashed border-gray-200",
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
            "w-full text-center rounded-lg py-3 font-semibold bg-[#7ff7ce]",
          ),
        ],
        [element.text("Sign In")],
      ),
    ],
  )
}

fn avatar(url: Option(String), size: String) -> Element(msg) {
  case url {
    Some(src) if src != "" ->
      html.img([
        attribute.src(src),
        attribute.alt(""),
        attribute.class(size <> " rounded-full object-cover shrink-0"),
      ])
    _ ->
      html.div(
        [attribute.class(size <> " rounded-full bg-gray-100 shrink-0")],
        [],
      )
  }
}

fn name_of(
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

@external(javascript, "../../../sonic_ffi.mjs", "render_markdown")
fn render_markdown(source: String) -> String
