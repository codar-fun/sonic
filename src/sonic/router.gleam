//// URL ⟷ route. One type, one parser, one printer.
////
//// Keeping the printer next to the parser means links in views are built from
//// the same definition that matches them, so a renamed path cannot leave dead
//// links behind — it stops compiling instead.

import gleam/list
import gleam/string

pub type Route {
  Home
  EventDetail(id: String)
  EventShare(id: String)
  EventComment(id: String)
  GroupHome(handle: String)
  Communities
  GroupCreate
  PopupCities
  Register
  EventCreate(handle: String)
  BadgeDetail(id: String)
  BadgeClassDetail(id: String)
  Schedule(handle: String)
  ScheduleCompact(handle: String)
  ScheduleVenue(handle: String)
  ScheduleWeek(handle: String)
  Venues(handle: String)
  Tracks(handle: String)
  Profile(handle: String)
  ProfileEdit(handle: String)
  Search
  MyEvents
  SetLanguage
  Signin
  SigninWallet
  SigninNonce
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
    ["event", "detail", id] -> EventDetail(id)
    ["event", "detail", id, "comment"] -> EventComment(id)
    ["event", "share", id] -> EventShare(id)
    // `detail` is a path segment, not a group handle. Without this guard
    // /event/detail (the id-less form) would resolve to a group named
    // "detail" and 404 from the API instead of from here — a confusing way to
    // report a malformed URL.
    ["event", "detail"] -> NotFound
    // Same guard for `share`: without it /event/share resolves to a group
    // literally named "share".
    ["event", "share"] -> NotFound
    ["event", handle] -> GroupHome(handle)
    ["event", handle, "schedule"] -> Schedule(handle)
    ["event", handle, "venues"] -> Venues(handle)
    ["event", handle, "tracks"] -> Tracks(handle)
    ["event", handle, "create"] -> EventCreate(handle)
    ["profile", handle] -> Profile(handle)
    ["profile", handle, "edit"] -> ProfileEdit(handle)
    ["event", handle, "schedule", "list"] -> Schedule(handle)
    ["event", handle, "schedule", "compact"] -> ScheduleCompact(handle)
    ["event", handle, "schedule", "venue"] -> ScheduleVenue(handle)
    ["event", handle, "schedule", "week"] -> ScheduleWeek(handle)
    ["events", id] -> EventDetail(id)
    ["communities"] -> Communities
    ["group", "create"] -> GroupCreate
    ["popup-city"] -> PopupCities
    ["register"] -> Register
    ["search"] -> Search
    ["my-events", _] -> MyEvents
    ["lang"] -> SetLanguage
    ["badge", id] -> BadgeDetail(id)
    ["badge-class", id] -> BadgeClassDetail(id)
    ["signin"] -> Signin
    ["signin", "verify"] -> SigninVerify
    ["signin", "wallet"] -> SigninWallet
    ["signin", "nonce"] -> SigninNonce
    ["signout"] -> Signout
    ["healthz"] -> Health
    _ -> NotFound
  }
}

/// Build the canonical path for a route.
pub fn href(route: Route) -> String {
  case route {
    Home -> "/"
    EventDetail(id) -> "/event/detail/" <> id
    EventShare(id) -> "/event/share/" <> id
    EventComment(id) -> "/event/detail/" <> id <> "/comment"
    GroupHome(handle) -> "/event/" <> handle
    Communities -> "/communities"
    GroupCreate -> "/group/create"
    PopupCities -> "/popup-city"
    Register -> "/register"
    EventCreate(handle) -> "/event/" <> handle <> "/create"
    BadgeDetail(id) -> "/badge/" <> id
    BadgeClassDetail(id) -> "/badge-class/" <> id
    Schedule(handle) -> "/event/" <> handle <> "/schedule"
    ScheduleCompact(handle) -> "/event/" <> handle <> "/schedule/compact"
    ScheduleVenue(handle) -> "/event/" <> handle <> "/schedule/venue"
    ScheduleWeek(handle) -> "/event/" <> handle <> "/schedule/week"
    Venues(handle) -> "/event/" <> handle <> "/venues"
    Tracks(handle) -> "/event/" <> handle <> "/tracks"
    Profile(handle) -> "/profile/" <> handle
    ProfileEdit(handle) -> "/profile/" <> handle <> "/edit"
    Search -> "/search"
    MyEvents -> "/my-events/attended"
    SetLanguage -> "/lang"
    Signin -> "/signin"
    SigninVerify -> "/signin/verify"
    SigninWallet -> "/signin/wallet"
    SigninNonce -> "/signin/nonce"
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
