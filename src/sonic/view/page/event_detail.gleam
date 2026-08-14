//// A single event.
////
//// Structure follows seastar-app's `event/detail/[eventid]/page.tsx`: a
//// `page-width !pt-4 !pb-12` wrapper, then a column pair that reverses at the
//// `sm` breakpoint — the cover is first in source order but second on wide
//// screens (`order-1 sm:order-2`), so mobile leads with the image and desktop
//// leads with the text, exactly as upstream.

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/event as event_api
import sonic/api/types.{type Event}
import sonic/view/badge
import sonic/view/event_time

pub fn view(event: Event) -> Element(msg) {
  html.div([attribute.class("page-width !pt-4 !pb-12")], [
    html.div(
      [
        attribute.class(
          "flex flex-row items-center justify-between sm:mb-8 mb-4",
        ),
      ],
      [
        html.a(
          [attribute.href("/"), attribute.class("flex-row-item-center text-sm")],
          [element.text("← Back")],
        ),
      ],
    ),
    html.div([attribute.class("flex flex-col sm:flex-row")], [
      html.div(
        [
          attribute.class(
            "min-w-[324px] sm:max-w-[324px] mb-8 order-1 sm:order-2 sm:mb-0",
          ),
        ],
        [cover(event.cover)],
      ),
      html.div([attribute.class("flex-1 sm:mr-9 order-2 sm:order-1")], [
        html.div([attribute.class("text-4xl font-semibold w-full")], [
          element.text(event.title),
        ]),
        track(event),
        badges(event),
        details(event),
        notes(event.notes),
        links(event),
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

fn track(event: Event) -> Element(msg) {
  case event.track {
    Some(t) ->
      case t.title {
        Some(title) if title != "" ->
          html.div(
            [attribute.class("flex-row-item-center gap-1.5 text-lg mt-1")],
            [element.text(title)],
          )
        _ -> element.none()
      }
    None -> element.none()
  }
}

/// Status badges, in the original's order.
///
/// `past`/`ongoing`/`upcoming` are derived from the event's own times in the
/// upstream app; without a clock available here only the states the payload
/// states outright are shown, rather than guessing at a comparison that would
/// be wrong in half the world's timezones.
fn badges(event: Event) -> Element(msg) {
  let flags =
    [
      case event.visibility {
        "private" -> Some(#(badge.Private, "Private"))
        _ -> None
      },
      case event.status {
        "pending" -> Some(#(badge.Pending, "Pending"))
        "cancelled" -> Some(#(badge.Cancel, "Cancelled"))
        _ -> None
      },
    ]
    |> list.filter_map(fn(flag) {
      case flag {
        Some(pair) -> Ok(badge.view(pair.0, pair.1))
        None -> Error(Nil)
      }
    })

  case flags {
    [] -> element.none()
    _ ->
      html.div(
        [
          attribute.class(
            "flex-row-item-center my-3 gap-3 overflow-auto !flex-wrap",
          ),
        ],
        flags,
      )
  }
}

fn details(event: Event) -> Element(msg) {
  html.div([attribute.class("border-gray-200 border rounded-lg p-4 mt-6")], [
    row(
      Some(event_time.range_with_zone(
        event.start_time,
        event.end_time,
        event.timezone,
      )),
    ),
    row(location(event)),
    row(host(event)),
    row(Some(attendance(event))),
    tags(event.tags),
  ])
}

fn row(value: Option(String)) -> Element(msg) {
  case value {
    Some(text) if text != "" ->
      html.div(
        [attribute.class("flex-row-item-center text-sm mt-2 first:mt-0")],
        [
          element.text(text),
        ],
      )
    _ -> element.none()
  }
}

fn location(event: Event) -> Option(String) {
  case event.place, event.venue {
    Some(p), _ -> first_present([p.title, p.formatted_address, p.location])
    None, Some(v) -> first_present([v.title, v.location])
    None, None -> None
  }
}

fn host(event: Event) -> Option(String) {
  let name = case event.group, event.owner {
    Some(g), _ -> first_present([g.nickname, g.name])
    None, Some(o) -> first_present([o.nickname, o.name])
    None, None -> None
  }
  case name {
    Some(value) -> Some("Hosted by " <> value)
    None -> None
  }
}

fn attendance(event: Event) -> String {
  let count = int.to_string(event.participant_count)
  let base = case event.max_participant {
    Some(max) -> count <> " of " <> int.to_string(max) <> " attending"
    None -> count <> " attending"
  }
  case event.require_approval {
    True -> base <> " · approval required"
    False -> base
  }
}

fn tags(values: List(String)) -> Element(msg) {
  case values {
    [] -> element.none()
    _ ->
      html.div(
        [attribute.class("flex-row-item-center mt-3 gap-2 !flex-wrap")],
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

fn notes(value: Option(String)) -> Element(msg) {
  case value {
    Some(text) if text != "" ->
      html.div([attribute.class("mt-6")], [
        html.div([attribute.class("font-semibold mb-2")], [
          element.text("About"),
        ]),
        html.div([attribute.class("whitespace-pre-wrap text-sm")], [
          element.text(text),
        ]),
      ])
    _ -> element.none()
  }
}

fn links(event: Event) -> Element(msg) {
  let entries =
    [
      #("Add to calendar", Some(event_api.calendar_url(event.id))),
      #("Join online", event.meeting_url),
      #("More info", event.external_url),
    ]
    |> list.filter_map(fn(entry) {
      case entry.1 {
        Some(url) if url != "" ->
          Ok(
            html.a(
              [
                attribute.href(url),
                attribute.class("flex-row-item-center text-sm underline"),
              ],
              [element.text(entry.0)],
            ),
          )
        _ -> Error(Nil)
      }
    })

  case entries {
    [] -> element.none()
    _ ->
      html.div(
        [attribute.class("flex-row-item-center mt-6 gap-4 !flex-wrap")],
        entries,
      )
  }
}

fn first_present(values: List(Option(String))) -> Option(String) {
  case values {
    [Some(value), ..] if value != "" -> Some(value)
    [_, ..rest] -> first_present(rest)
    [] -> None
  }
}
