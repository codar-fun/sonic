//// The event index.

import gleam/int
import gleam/list
import gleam/option.{None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{type Event, type Page}
import sonic/router
import sonic/view/event_time

pub fn view(page: Page(Event)) -> Element(msg) {
  html.div([], [
    html.h1([], [element.text("Events")]),
    html.p([attribute.class("meta")], [
      element.text(
        int.to_string(page.meta.total) <> " events · page " <> int.to_string(page.meta.page),
      ),
    ]),
    case page.data {
      [] -> html.p([attribute.class("empty")], [element.text("Nothing here yet.")])
      events -> html.ul([attribute.class("list")], list.map(events, card))
    },
  ])
}

fn card(event: Event) -> Element(msg) {
  html.li([attribute.class("card")], [
    html.a([attribute.href(router.href(router.EventDetail(event.id)))], [
      html.h3([], [element.text(event.title)]),
      html.p([attribute.class("meta")], [
        element.text(event_time.range(event.start_time, event.end_time)),
      ]),
      byline(event),
    ]),
  ])
}

fn byline(event: Event) -> Element(msg) {
  let group = case event.group {
    Some(g) -> display_name(g.nickname, g.name)
    None -> None
  }
  case group {
    Some(name) ->
      html.p([attribute.class("meta")], [element.text("by " <> name)])
    None -> element.none()
  }
}

fn display_name(
  nickname: option.Option(String),
  name: option.Option(String),
) -> option.Option(String) {
  case nickname, name {
    Some(n), _ if n != "" -> Some(n)
    _, Some(n) if n != "" -> Some(n)
    _, _ -> None
  }
}
