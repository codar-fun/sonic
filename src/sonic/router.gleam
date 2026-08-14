//// URL ⟷ route. One type, one parser, one printer.
////
//// Keeping the printer next to the parser means links in views are built from
//// the same definition that matches them, so a renamed path cannot leave dead
//// links behind — it stops compiling instead.

import gleam/list
import gleam/string

pub type Route {
  Home
  EventList
  EventDetail(id: String)
  GroupHome(handle: String)
  Communities
  Signin
  SigninVerify
  Signout
  Health
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
    [] -> Home
    ["discover"] -> Home
    ["events"] -> EventList
    ["event", "detail", id] -> EventDetail(id)
    // `detail` is a path segment, not a group handle. Without this guard
    // /event/detail (the id-less form) would resolve to a group named
    // "detail" and 404 from the API instead of from here — a confusing way to
    // report a malformed URL.
    ["event", "detail"] -> NotFound
    ["event", handle] -> GroupHome(handle)
    ["events", id] -> EventDetail(id)
    ["communities"] -> Communities
    ["signin"] -> Signin
    ["signin", "verify"] -> SigninVerify
    ["signout"] -> Signout
    ["healthz"] -> Health
    _ -> NotFound
  }
}

/// Build the canonical path for a route.
pub fn href(route: Route) -> String {
  case route {
    Home -> "/"
    EventList -> "/events"
    EventDetail(id) -> "/event/detail/" <> id
    GroupHome(handle) -> "/event/" <> handle
    Communities -> "/communities"
    Signin -> "/signin"
    SigninVerify -> "/signin/verify"
    Signout -> "/signout"
    Health -> "/healthz"
    NotFound -> "/404"
  }
}

fn unwrap_or(result: Result(a, b), fallback: a) -> a {
  case result {
    Ok(value) -> value
    Error(_) -> fallback
  }
}
