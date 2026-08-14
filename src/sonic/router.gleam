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
  BadgeDetail(id: String)
  BadgeClassDetail(id: String)
  Schedule(handle: String)
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
    ["event", handle, "schedule"] -> Schedule(handle)
    ["event", handle, "schedule", "list"] -> Schedule(handle)
    ["events", id] -> EventDetail(id)
    ["communities"] -> Communities
    ["badge", id] -> BadgeDetail(id)
    ["badge-class", id] -> BadgeClassDetail(id)
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
    BadgeDetail(id) -> "/badge/" <> id
    BadgeClassDetail(id) -> "/badge-class/" <> id
    Schedule(handle) -> "/event/" <> handle <> "/schedule"
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
