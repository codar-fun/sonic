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
import sonic/view/default_cover
import sonic/view/event_time
import sonic/view/image

pub fn view(event: Event, repeats: Option(String)) -> Element(msg) {
  html.div([attribute.class("page-width !pt-4 !pb-12")], [
    top_bar(event),
    html.div([attribute.class("flex flex-col sm:flex-row")], [
      html.div(
        [
          attribute.class(
            "min-w-[324px] sm:max-w-[324px] mb-8 order-1 sm:order-2 sm:mb-0",
          ),
        ],
        [cover(event), participate()],
      ),
      html.div([attribute.class("flex-1 min-w-0 sm:mr-9 order-2 sm:order-1")], [
        html.div([attribute.class("text-4xl font-semibold w-full")], [
          element.text(event.title),
        ]),
        tag_row(event),
        host_row(event),
        date_row(event, repeats),
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
                48,
                "w-6 h-6 rounded-full",
              ),
              // Truncated, not wrapped: a long community name pushed the
              // Share control off the row.
              html.span(
                [
                  attribute.class(
                    "font-semibold font-sm overflow-hidden overflow-ellipsis whitespace-nowrap max-w-[120px] sm:max-w-max",
                  ),
                ],
                [element.text(name_of(group.nickname, group.name, group.id))],
              ),
            ],
          )
        None -> html.div([], [])
      },
      // Points at the share page. This linked to /event/detail/<id> — the
      // page it is already on — so the button did nothing.
      html.a(
        [
          attribute.href("/event/share/" <> event.id),
          attribute.class(
            "cursor-pointer hover:bg-gray-300 flex-row-item-center ml-2 h-8 font-semibold text-base bg-gray-200 rounded-lg px-2",
          ),
        ],
        [
          html.i([attribute.class("uil-external-link-alt ")], []),
          // Icon-only on narrow screens, where the label would crowd the row.
          html.span([attribute.class("sm:inline hidden ml-1 ")], [
            element.text("Share"),
          ]),
        ],
      ),
    ],
  )
}

/// Status badge and tags on one line. Upstream marks each tag with a coloured
/// dot; the colour is derived from the tag there, so a fixed palette is used
/// here rather than inventing a per-tag colour that would not match anyway.
fn tag_row(event: Event) -> Element(msg) {
  // Each tag's dot is a deterministic hash of its name, the same one upstream
  // uses — a fixed palette would have given every tag a plausible colour that
  // matched nothing.
  let tags =
    list.map(event.tags, fn(tag) {
      html.div([attribute.class("flex-row-item-center gap-1.5 text-sm")], [
        html.i(
          [
            attribute.class("w-2 h-2 rounded-full"),
            attribute.styles([#("background-color", label_color(tag))]),
          ],
          [],
        ),
        html.div([], [element.text(tag)]),
      ])
    })

  case has_status(event), tags {
    False, [] -> element.none()
    _, _ ->
      html.div(
        [
          attribute.class(
            "flex-row-item-center my-3 gap-3 overflow-auto !flex-wrap",
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
    // An event whose end time has gone by is marked Past. This is the one
    // badge that cannot be read off the payload — it needs a clock.
    _, _ -> has_passed(event.end_time)
  }
}

fn status_badge(event: Event) -> Element(msg) {
  case event.status, event.visibility {
    "cancelled", _ -> badge.view(badge.Cancel, "Cancelled")
    "pending", _ -> badge.view(badge.Pending, "Pending")
    _, "private" -> badge.view(badge.Private, "Private")
    _, _ ->
      case has_passed(event.end_time) {
        True -> badge.view(badge.Past, "Past")
        False -> element.none()
      }
  }
}

/// The host, then every co-host from `event_roles`, on one scrollable row —
/// upstream shows all of them, not just the owner.
fn host_row(event: Event) -> Element(msg) {
  let owner = case event.owner {
    Some(o) -> [
      person(
        o.image_url,
        o.id,
        name_of(o.nickname, o.name, o.id),
        "Host",
        o.name,
      ),
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
        None,
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

/// A host links to their profile when they have a handle. Co-hosts carried on
/// `event_roles` often have only a display name, so those stay plain text
/// rather than linking somewhere that does not resolve.
fn person(
  picture: Option(String),
  id: String,
  name: String,
  role: String,
  handle: Option(String),
) -> Element(msg) {
  let inner = [
    image.avatar_or_default(picture, id, 48, "w-11 h-11 rounded-full mr-2"),
    html.div([], [
      html.div([attribute.class("font-semibold text-sm text-nowrap")], [
        element.text(name),
      ]),
      html.div([attribute.class("text-xs text-gray-400")], [element.text(role)]),
    ]),
  ]
  let classes =
    "my-3 shrink-0 grow-0 inline-flex flex-row items-center mr-6 overflow-auto"

  case handle {
    Some(value) if value != "" ->
      html.a(
        [attribute.href("/profile/" <> value), attribute.class(classes)],
        inner,
      )
    _ -> html.div([attribute.class(classes)], inner)
  }
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

fn date_row(event: Event, repeats: Option(String)) -> Element(msg) {
  html.div([attribute.class("flex-row-item-center my-4")], [
    html.div(
      [
        attribute.class(
          "mr-2 flex-shrink-0 w-9 h-9 flex flex-row items-center justify-center border border-gray-300 rounded-lg",
        ),
      ],
      [html.i([attribute.class("uil-calendar-alt text-base")], [])],
    ),
    html.div([], [
      html.div([attribute.class("font-semibold text-base")], [
        element.text(event_time.in_zone_date(event.start_time, event.timezone)),
      ]),
      html.div([attribute.class("text-gray-400 text-base")], [
        element.text(event_time.in_zone_range(
          event.start_time,
          event.end_time,
          event.timezone,
        )),
      ]),
      // Only shown when the event belongs to a recurrence — the interval comes
      // from /recurring/:id, not from the event itself.
      case repeats {
        Some(interval) if interval != "" ->
          html.div(
            [attribute.class("text-xs cursor-pointer flex-row-item-center text-blue-400")],
            [element.text("Repeating Events ,every " <> interval)],
          )
        _ -> element.none()
      },
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
      html.div([attribute.class("flex-row-item-center my-4")], [
        html.div(
          [
            attribute.class(
              "mr-2 flex-shrink-0 w-9 h-9 flex flex-row items-center justify-center border border-gray-300 rounded-lg",
            ),
          ],
          [html.i([attribute.class("uil-location-point text-base")], [])],
        ),
        html.div([attribute.class("min-w-0")], [
          case name {
            Some(text) ->
              html.div([attribute.class("font-semibold text-base")], [
                element.text(text),
              ])
            None -> element.none()
          },
          case address {
            Some(text) ->
              html.div([attribute.class("text-gray-400 text-base")], [
                element.text(text),
              ])
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
    [attribute.class("flex font-semibold mt-6 scroll-mt-4"), attribute("role", "tablist")],
    [
      html.button(
        [
          attribute.type_("button"),
          attribute("role", "tab"),
          attribute("aria-selected", "true"),
          attribute.class(
            "flex-1 min-w-0 text-center cursor-pointer text-sm sm:text-base py-1 px-1 sm:px-2 relative whitespace-nowrap",
          ),
        ],
        [
          html.span([attribute.class("relative z-10")], [
            element.text("Content"),
          ]),
          // The selected tab's underline is an image upstream, not a border —
          // it is a tapered brush stroke that a border cannot draw.
          html.img([
            attribute.src("/static/images/tab_bg.png"),
            attribute.alt(""),
            attribute.width(90),
            attribute.height(12),
            attribute.class(
              "w-[64px] sm:w-[80px] absolute left-1/2 -translate-x-1/2 bottom-0",
            ),
          ]),
        ],
      ),
      html.button(
        [
          attribute.type_("button"),
          attribute("role", "tab"),
          attribute("aria-selected", "false"),
          attribute.class(
            "flex-1 min-w-0 text-center cursor-pointer text-sm sm:text-base py-1 px-1 sm:px-2 relative whitespace-nowrap border-l-[1px] border-gray-200",
          ),
        ],
        [
          html.span([attribute.class("relative z-10")], [
            element.text("Participants"),
            html.span([attribute.class("text-xs ml-0.5")], [
              element.text("(" <> int.to_string(event.participant_count) <> ")"),
            ]),
          ]),
        ],
      ),
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
    html.div([attribute.class("font-semibold")], [element.text("Comments")]),
    html.div([attribute.class("py-4 flex flex-row w-full !items-start")], [
      // The signed-out avatar is the shipped default, as upstream renders it.
      html.img([
        attribute.src("/static/images/default_avatar/avatar_1.png"),
        attribute.alt(""),
        attribute.class("w-9 h-9 rounded-full mr-2 border"),
      ]),
      html.div([attribute.class("flex-1 bg-secondary rounded-lg p-2")], [
        html.textarea(
          [
            attribute.class(
              "flex w-full bg-secondary px-3 py-2 text-base outline-none min-h-[60px] !border-0 md:text-sm",
            ),
            attribute.placeholder("Input comment"),
            attribute.disabled(True),
          ],
          "",
        ),
        html.div([attribute.class("flex-row-item-center justify-end")], [
          html.a(
            [
              attribute.href("/signin"),
              attribute.class(
                "font-semibold inline-flex items-center justify-center whitespace-nowrap rounded-lg bg-foreground text-white hover:opacity-80 h-7 px-3 text-xs mt-2",
              ),
            ],
            [element.text("Sign in to send a comment")],
          ),
        ]),
      ]),
    ]),
  ])
}

fn cover(event: Event) -> Element(msg) {
  case event.cover {
    // Shown whole rather than cropped to a square: this is the event's own
    // artwork, and a centre-crop cut the ends off wide covers.
    Some(src) if src != "" ->
      html.img([
        attribute.src(image.banner(src)),
        attribute.alt(""),
        attribute.class("max-w-[450px] w-full mx-auto"),
        ..image.eager()
      ])
    // Same generated card as the share page — an event without artwork still
    // has a title, a time and a place worth showing.
    _ ->
      html.div(
        [attribute.class("w-[324px] h-[324px] overflow-hidden mx-auto")],
        [default_cover.view(event, 324)],
      )
  }
}

/// The participate panel. Joining is a write path and is not built, so this
/// sends people to sign-in exactly as upstream does for a signed-out visitor.
fn participate() -> Element(msg) {
  html.div(
    [
      attribute.class(
        "flex flex-col justify-center items-center rounded-lg border-dashed border-2 p-3 my-3",
      ),
    ],
    [
      html.img([
        attribute.src("/static/images/balloon.png"),
        attribute.alt(""),
        attribute.class("w-12"),
      ]),
      html.div([attribute.class("text-sm font-semibold my-2")], [
        element.text("Sign in to participate in a fun event"),
      ]),
      html.a(
        [
          attribute.href("/signin"),
          attribute.class(
            "font-semibold inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-lg ring-offset-background transition-colors bg-special text-special-foreground hover:opacity-80 h-11 px-4 py-2 w-full",
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

@external(javascript, "../../../sonic_ffi.mjs", "label_color")
fn label_color(label: String) -> String

@external(javascript, "../../../sonic_ffi.mjs", "has_passed")
fn has_passed(iso: String) -> Bool
