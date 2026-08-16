//// The generated cover, for events with no picture of their own.
////
//// Upstream does not fall back to a grey box: it draws a card carrying the
//// event's title, start and place over a shipped background. That is what a
//// link to such an event previews as, so a blank rectangle is not a cosmetic
//// difference — it is the whole preview.
////
//// The card is authored at 452×452 with everything positioned absolutely, and
//// then scaled to fit whatever box it is placed in. Scaling rather than
//// re-laying-out is deliberate and matches upstream: the type sizes and offsets
//// stay in one proportion instead of needing a separate set per call site.

import gleam/float
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{type Event}
import sonic/view/event_time

/// Authored size. Every offset below is in this coordinate space.
const authored = 452.0

/// `box` is the side of the square this has to fit into, in pixels.
pub fn view(event: Event, box: Int) -> Element(msg) {
  let scale = int.to_float(box) /. authored

  html.div(
    [
      attribute.class("default-cover w-[452px] h-[452px]"),
      attribute.styles([#("transform", "scale(" <> format(scale) <> ")")]),
    ],
    contents(event),
  )
}

/// The list-card variant. Cards change size at the `sm` breakpoint, so the
/// scale is two Tailwind classes rather than one computed transform — an
/// inline style cannot carry a media query.
pub fn card(event: Event) -> Element(msg) {
  html.div(
    [
      attribute.class(
        "default-cover w-[452px] h-[452px] sm:scale-[0.309] scale-[0.22]",
      ),
    ],
    contents(event),
  )
}

fn contents(event: Event) -> List(Element(msg)) {
  [
      html.div(
        [
          attribute.class(
            "font-semibold text-[27px] webkit-box-clamp-2 max-h-[80px] w-[312px] absolute left-[76px] top-[78px]",
          ),
        ],
        [element.text(event.title)],
      ),
      html.div(
        [attribute.class("text-lg absolute font-semibold left-[76px] top-[178px]")],
        [
          element.text(event_time.in_zone_date(event.start_time, event.timezone)),
          html.br([]),
          element.text(start_clock(event)),
        ],
      ),
      case where(event) {
        Some(place) ->
          html.div(
            [
              attribute.class(
                "text-lg absolute font-semibold left-[76px] top-[240px]",
              ),
            ],
            [element.text(place)],
          )
        None -> element.none()
      },
  ]
}

/// The card shows only when the event starts, not the full range: `17:00 GMT+7`.
fn start_clock(event: Event) -> String {
  let range =
    event_time.in_zone_range(event.start_time, event.end_time, event.timezone)
  // `in_zone_range` gives "17:00 - 18:00 GMT+7"; the card wants the first time
  // and the offset, without the end.
  case string.split(range, " ") {
    [from, _dash, _to, ..rest] -> string.join([from, ..rest], " ")
    _ -> range
  }
}

fn where(event: Event) -> Option(String) {
  let venue = case event.venue {
    Some(v) -> first_present([v.title, v.location])
    None -> None
  }
  case venue {
    Some(_) -> venue
    None ->
      case event.place {
        Some(p) -> first_present([p.title, p.address])
        None -> None
      }
  }
}

fn first_present(values: List(Option(String))) -> Option(String) {
  case values {
    [Some(value), ..] if value != "" -> Some(value)
    [_, ..rest] -> first_present(rest)
    [] -> None
  }
}

/// Trimmed to six decimals: an unbounded float would put a slightly different
/// string in the markup on every render for no visible gain.
fn format(value: Float) -> String {
  float.to_string(int.to_float(float.round(value *. 1_000_000.0)) /. 1_000_000.0)
}
