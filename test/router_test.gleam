//// Router tests. The parser and the href printer live in one module so links
//// cannot drift from the routes that match them; these tests assert that
//// round trip explicitly.

import gleam/option.{type Option, None, Some}
import gleeunit/should
import sonic/server
import sonic/router.{
  EventDetail, EventList, EventShare, GroupHome, Home, NotFound,
}

/// seastar-app serves Discover at `/`, not an events list, so sonic does too.
pub fn root_is_the_home_page_test() {
  router.parse("/") |> should.equal(Home)
  router.parse("") |> should.equal(Home)
  router.parse("/discover") |> should.equal(Home)
}

pub fn events_path_is_the_list_test() {
  router.parse("/events") |> should.equal(EventList)
}

pub fn detail_paths_test() {
  router.parse("/event/detail/abc123") |> should.equal(EventDetail("abc123"))
  router.parse("/events/abc123") |> should.equal(EventDetail("abc123"))
}

/// Trailing slashes are a routing accident, not a different page.
pub fn trailing_slash_is_ignored_test() {
  router.parse("/events/") |> should.equal(EventList)
  router.parse("/event/detail/abc123/") |> should.equal(EventDetail("abc123"))
}

/// A query string belongs to the handler, not to route matching.
pub fn query_string_is_ignored_test() {
  router.parse("/events?page=2") |> should.equal(EventList)
  router.parse("/event/detail/x1?ref=share") |> should.equal(EventDetail("x1"))
}

pub fn unknown_paths_are_not_found_test() {
  router.parse("/nope") |> should.equal(NotFound)
  router.parse("/event/detail") |> should.equal(NotFound)
  router.parse("/a/b/c/d") |> should.equal(NotFound)
}

/// The point of keeping `parse` and `href` together: every route a view can
/// link to must match back to itself.
pub fn href_round_trips_test() {
  [Home, EventList, EventDetail("abc123")]
  |> should_round_trip
}

fn should_round_trip(routes: List(router.Route)) -> Nil {
  case routes {
    [] -> Nil
    [route, ..rest] -> {
      router.href(route) |> router.parse |> should.equal(route)
      should_round_trip(rest)
    }
  }
}

/// `/event/:handle` must not swallow the id-less detail path: without a guard
/// it resolves to a group literally named "detail".
pub fn detail_is_not_a_group_handle_test() {
  router.parse("/event/detail") |> should.equal(NotFound)
  router.parse("/event/share") |> should.equal(NotFound)
  router.parse("/event/share/abc") |> should.equal(EventShare("abc"))
  router.parse("/event/shanhaiwoo") |> should.equal(GroupHome("shanhaiwoo"))
}

/// The week view is a distinct route, not a query on the list view. Without
/// this it fell through to the group page for a group named "week".
pub fn schedule_week_route_test() {
  router.parse("/event/4seas/schedule/week")
  |> should.equal(router.ScheduleWeek("4seas"))

  router.href(router.ScheduleWeek("4seas"))
  |> should.equal("/event/4seas/schedule/week")
}

/// `return` arrives in a URL, so a sign-in link could otherwise hand the
/// visitor to another site once they have signed in. A leading `//` is
/// protocol-relative — absolute in effect — which is the case a plain
/// "starts with /" check lets through.
pub fn return_path_must_be_same_site_test() {
  server.safe_return(Some("/event/4seas")) |> should.equal(Some("/event/4seas"))
  server.safe_return(Some("//evil.example/x")) |> should.equal(None)
  server.safe_return(Some("https://evil.example")) |> should.equal(None)
  server.safe_return(None) |> should.equal(None)
}
