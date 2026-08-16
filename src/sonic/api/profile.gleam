//// Profile and venue endpoints.
////
//// `/users/:handle` rather than `/profiles/:handle`: the SDK calls the concept
//// a profile but the route is users, and the route is what answers.

import gleam/dynamic/decode
import gleam/int
import gleam/javascript/promise.{type Promise}
import gleam/option.{Some}
import sonic/api/client.{type ApiResult, type Auth}
import sonic/api/decoders
import sonic/api/types.{
  type Badge, type Event, type Membership, type Page, type SearchResults,
  type UserProfile, type VenueDetail,
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
/// `GET /events?<filter>=<handle>` — one of a profile's four event lists.
///
/// The filter name is the whole difference between them: `attendee_id`,
/// `owner_id`, `co_host_id`, `starred_id`. All four are public.
pub fn events(
  filter filter: String,
  handle handle: String,
  auth auth: Auth,
) -> Promise(ApiResult(Page(Event))) {
  client.get(
    path: "/events",
    query: [#(filter, Some(handle)), #("limit", Some("100"))],
    auth: auth,
    expect: decoders.page(of: decoders.event()),
  )
}

/// `GET /users/:handle/groups` — the groups a profile belongs to.
///
/// Answers with a bare array rather than the `{data, meta}` envelope every
/// other list endpoint uses, so it needs its own decoder.
pub fn groups(
  handle handle: String,
  auth auth: Auth,
) -> Promise(ApiResult(List(Membership))) {
  client.get(
    path: "/users/" <> handle <> "/groups",
    query: [],
    auth: auth,
    expect: decode.list(decoders.membership()),
  )
}

/// `GET /badges?owner_id=<handle>` — the badges a profile holds.
pub fn badges(
  handle handle: String,
  auth auth: Auth,
) -> Promise(ApiResult(Page(Badge))) {
  client.get(
    path: "/badges",
    query: [#("owner_id", Some(handle)), #("limit", Some("100"))],
    auth: auth,
    expect: decoders.page(of: decoders.badge()),
  )
}

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
