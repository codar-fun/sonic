//// Event endpoints.
////
//// Each function is one call site: a path, its parameters, and the decoder for
//// what comes back. No logic lives here — sorting, grouping and formatting are
//// the view layer's job, so these stay trivially readable against the API.

import gleam/int
import gleam/javascript/promise.{type Promise}
import gleam/option.{type Option, None, Some}
import sonic/api/client.{type ApiResult, type Auth}
import sonic/api/decoders
import sonic/api/types.{type Discover, type Event, type Page, type Participant}

/// `GET /events` — a page of public events, newest page first.
pub fn list(
  page page: Int,
  limit limit: Int,
  auth auth: Auth,
) -> Promise(ApiResult(Page(Event))) {
  client.get(
    path: "/events",
    query: [
      #("page", Some(int.to_string(page))),
      #("limit", Some(int.to_string(limit))),
    ],
    auth: auth,
    expect: decoders.page(of: decoders.event()),
  )
}

/// `GET /events/:id` — one event, with the detail fields populated.
pub fn detail(id id: String, auth auth: Auth) -> Promise(ApiResult(Event)) {
  client.get(
    path: "/events/" <> id,
    query: [],
    auth: auth,
    expect: decoders.event(),
  )
}

/// `GET /events` scoped to a group handle, used by the group landing page.
pub fn list_for_group(
  handle handle: String,
  page page: Int,
  limit limit: Int,
  auth auth: Auth,
) -> Promise(ApiResult(Page(Event))) {
  client.get(
    path: "/events",
    query: [
      #("group_handle", Some(handle)),
      #("page", Some(int.to_string(page))),
      #("limit", Some(int.to_string(limit))),
    ],
    auth: auth,
    expect: decoders.page(of: decoders.event()),
  )
}

/// Events the signed-in user is attending. Requires a token; without one the
/// API answers 401 and the caller gets `HttpError(401, _)` rather than an
/// empty list, so "not signed in" never masquerades as "nothing to show".
pub fn mine(auth auth: Auth) -> Promise(ApiResult(Page(Event))) {
  client.get(
    path: "/events/my_events",
    query: [#("page", Some("1")), #("limit", Some("20"))],
    auth: auth,
    expect: decoders.page(of: decoders.event()),
  )
}

/// The upstream app links out to an `.ics` file rather than building one, so
/// this returns the URL instead of fetching it.
/// `GET /events/:id/participants` — who is attending.
///
/// Public: the detail page's Participants tab shows this to anyone, signed in
/// or not, exactly as upstream does.
pub fn participants(id id: String) -> Promise(ApiResult(Page(Participant))) {
  client.get(
    path: "/events/" <> id <> "/participants",
    query: [],
    auth: None,
    expect: decoders.page(of: decoders.participant()),
  )
}

/// `GET /recurring/:id` — the series an event belongs to.
///
/// Only the interval is decoded. The payload also carries every instance,
/// which the detail page does not show and which grows without bound on a
/// weekly series that has been running for a year.
pub fn recurring_interval(id id: String) -> Promise(ApiResult(String)) {
  client.get(
    path: "/recurring/" <> id,
    query: [],
    auth: None,
    expect: decoders.recurring_interval(),
  )
}

pub fn calendar_url(id: String) -> String {
  client.base_url <> "/api/v1/events/" <> id <> "/calendar.ics"
}

/// Convenience for pages that only need the first page of results.
pub fn first_page(
  limit limit: Int,
  auth auth: Auth,
) -> Promise(ApiResult(Page(Event))) {
  list(page: 1, limit: limit, auth: auth)
}

/// Unwrap an optional token from a request context.
pub fn token(value: Option(String)) -> Auth {
  case value {
    Some("") -> None
    other -> other
  }
}

/// `GET /discover` — the home page's whole payload in one request.
///
/// Lives here rather than in its own module because it is one call; if the
/// home page grows more sources this moves to `sonic/api/discover`.
pub fn discover() -> Promise(ApiResult(Discover)) {
  client.get(
    path: "/discover",
    query: [],
    auth: None,
    expect: decoders.discover(),
  )
}
