//// URL ⟷ route. One type, one parser, one printer.
////
//// Keeping the printer next to the parser means links in views are built from
//// the same definition that matches them, so a renamed path cannot leave dead
//// links behind — it stops compiling instead.

import gleam/list
import gleam/string

pub type Route {
  EventList
  EventDetail(id: String)
  NotFound
}

/// Parse a request path. Query strings and trailing slashes are ignored.
pub fn parse(path: String) -> Route {
  let segments =
    path
    |> string.split("?")
    |> list.first
    |> unwrap_or(path)
    |> string.split("/")
    |> list.filter(fn(segment) { segment != "" })

  case segments {
    [] -> EventList
    ["events"] -> EventList
    ["event", "detail", id] -> EventDetail(id)
    ["events", id] -> EventDetail(id)
    _ -> NotFound
  }
}

/// Build the canonical path for a route.
pub fn href(route: Route) -> String {
  case route {
    EventList -> "/"
    EventDetail(id) -> "/event/detail/" <> id
    NotFound -> "/404"
  }
}

fn unwrap_or(result: Result(a, b), fallback: a) -> a {
  case result {
    Ok(value) -> value
    Error(_) -> fallback
  }
}
