//// Profile and venue endpoints.
////
//// `/users/:handle` rather than `/profiles/:handle`: the SDK calls the concept
//// a profile but the route is users, and the route is what answers.

import gleam/int
import gleam/javascript/promise.{type Promise}
import gleam/option.{Some}
import sonic/api/client.{type ApiResult, type Auth}
import sonic/api/decoders
import sonic/api/types.{
  type Page, type SearchResults, type UserProfile, type VenueDetail,
}

/// `GET /users/:handle`
pub fn detail(
  handle handle: String,
  auth auth: Auth,
) -> Promise(ApiResult(UserProfile)) {
  client.get(
    path: "/users/" <> handle,
    query: [],
    auth: auth,
    expect: decoders.user_profile(),
  )
}

/// `GET /venues?group_id=…` — a group's venues.
pub fn venues(
  group_id group_id: String,
  auth auth: Auth,
) -> Promise(ApiResult(Page(VenueDetail))) {
  client.get(
    path: "/venues",
    query: [#("group_id", Some(group_id)), #("limit", Some(int.to_string(100)))],
    auth: auth,
    expect: decoders.page(of: decoders.venue_detail()),
  )
}

/// `GET /search?keyword=…` — events, groups, users and badge classes at once.
///
/// The parameter is `keyword`, not `query`: `query` is accepted and silently
/// matches nothing, which looks like "no results" rather than a mistake.
pub fn search(
  keyword keyword: String,
  auth auth: Auth,
) -> Promise(ApiResult(SearchResults)) {
  client.get(
    path: "/search",
    query: [#("keyword", Some(keyword))],
    auth: auth,
    expect: decoders.search_results(),
  )
}
