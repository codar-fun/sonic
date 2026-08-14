//// A single event.

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/event as event_api
import sonic/api/types.{type Event}
import sonic/view/event_time

pub fn view(event: Event) -> Element(msg) {
  html.article([], [
    cover(event.cover),
    html.h1([], [element.text(event.title)]),
    html.p([attribute.class("meta")], [
      element.text(event_time.range_with_zone(
        event.start_time,
        event.end_time,
        event.timezone,
      )),
    ]),
    host(event),
    location(event),
    tags(event.tags),
    attendance(event),
    notes(event.notes),
    links(event),
  ])
}

fn cover(url: Option(String)) -> Element(msg) {
  case url {
    Some(src) if src != "" ->
      html.img([
        attribute.src(src),
        attribute.alt(""),
        attribute.class("cover"),
      ])
    _ -> element.none()
  }
}

fn host(event: Event) -> Element(msg) {
  let name = case event.group, event.owner {
    Some(g), _ -> pick(g.nickname, g.name)
    None, Some(o) -> pick(o.nickname, o.name)
    None, None -> None
  }
  case name {
    Some(n) -> html.p([attribute.class("meta")], [element.text("Hosted by " <> n)])
    None -> element.none()
  }
}

fn location(event: Event) -> Element(msg) {
  let text = case event.place, event.venue {
    Some(p), _ -> first_present([p.title, p.formatted_address, p.location])
    None, Some(v) -> first_present([v.title, v.location])
    None, None -> None
  }
  case text {
    Some(where) ->
      html.p([attribute.class("meta")], [element.text("At " <> where)])
    None -> element.none()
  }
}

fn tags(values: List(String)) -> Element(msg) {
  case values {
    [] -> element.none()
    _ ->
      html.ul(
        [attribute.class("tags")],
        list.map(values, fn(tag) {
          html.li([attribute.class("tag")], [element.text(tag)])
        }),
      )
  }
}

fn attendance(event: Event) -> Element(msg) {
  let count = int.to_string(event.participant_count)
  let text = case event.max_participant {
    Some(max) -> count <> " of " <> int.to_string(max) <> " attending"
    None -> count <> " attending"
  }
  let approval = case event.require_approval {
    True -> " · approval required"
    False -> ""
  }
  html.p([attribute.class("meta")], [element.text(text <> approval)])
}

fn notes(value: Option(String)) -> Element(msg) {
  case value {
    Some(text) if text != "" ->
      html.div([], [
        html.h2([], [element.text("About")]),
        html.p([attribute.class("notes")], [element.text(text)]),
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
        Some(url) if url != "" -> Ok(#(entry.0, url))
        _ -> Error(Nil)
      }
    })

  case entries {
    [] -> element.none()
    _ ->
      html.div([], [
        html.h2([], [element.text("Links")]),
        html.ul(
          [attribute.class("list")],
          list.map(entries, fn(entry) {
            html.li([], [
              html.a([attribute.href(entry.1)], [element.text(entry.0)]),
            ])
          }),
        ),
      ])
  }
}

fn pick(first: Option(String), second: Option(String)) -> Option(String) {
  first_present([first, second])
}

fn first_present(values: List(Option(String))) -> Option(String) {
  case values {
    [Some(value), ..] if value != "" -> Some(value)
    [_, ..rest] -> first_present(rest)
    [] -> None
  }
}
