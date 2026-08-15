//// Group endpoints.
////
//// Groups are addressed by handle in URLs and by id in most payloads; the
//// handle is the `name` field. These take the handle, matching what the router
//// hands over.

import gleam/int
import gleam/javascript/promise.{type Promise}
import gleam/option.{type Option, Some}
import sonic/api/client.{type ApiResult, type Auth}
import sonic/api/decoders
import sonic/api/types.{
  type Event, type GroupDetail, type Membership, type Page, type TrackDetail,
}

/// `GET /groups/:handle` — one group's full record.
pub fn detail(
  handle handle: String,
  auth auth: Auth,
) -> Promise(ApiResult(GroupDetail)) {
  client.get(
    path: "/groups/" <> handle,
    query: [],
    auth: auth,
    expect: decoders.group_detail(),
  )
}

/// `GET /events?group_id=…` — that group's events.
///
/// The parameter is `group_id`, and it accepts a handle as well as a TSID.
/// `group_handle` is *not* a filter the API knows: it is accepted, ignored,
/// and answered with every event on the platform — which renders as a
/// plausible-looking page belonging to the wrong group.
pub fn events(
  handle handle: String,
  page page: Int,
  limit limit: Int,
  collection collection: String,
  auth auth: Auth,
) -> Promise(ApiResult(Page(Event))) {
  client.get(
    path: "/events",
    query: [
      #("group_id", Some(handle)),
      // The SDK calls this `collection`; upcoming/past is a server-side split,
      // not something to filter client-side against a clock we do not have.
      #("collection", Some(collection)),
      #("page", Some(int.to_string(page))),
      #("limit", Some(int.to_string(limit))),
    ],
    auth: auth,
    expect: decoders.page(of: decoders.event()),
  )
}

/// `GET /events?group_id=…&start_date=…&end_date=…` — a group's events inside
/// a date window.
///
/// The schedule asks for a window rather than a page: upstream loads one week
/// for the list and week views and one day for compact and venue, then groups
/// what comes back. Paging by count instead returned the group's entire
/// history, which is why the schedule was showing hundreds of past events
/// under a heading that says this week.
///
/// The limit matches upstream's 400 — the window bounds the result, and a
/// smaller page would silently cut a busy week short.
pub fn schedule_events(
  handle handle: String,
  from from: String,
  to to: String,
  timezone timezone: Option(String),
  auth auth: Auth,
) -> Promise(ApiResult(Page(Event))) {
  client.get(
    path: "/events",
    query: [
      #("group_id", Some(handle)),
      #("start_date", Some(from)),
      #("end_date", Some(to)),
      #("timezone", timezone),
      #("limit", Some("400")),
    ],
    auth: auth,
    expect: decoders.page(of: decoders.event()),
  )
}

/// `GET /groups/directory` — every active group, for `/communities`.
///
/// A different question from `/discover`'s curated slice: this is the full
/// list, which is why an untagged group appears here and nowhere else.
pub fn directory(
  page page: Int,
  limit limit: Int,
  auth auth: Auth,
) -> Promise(ApiResult(Page(GroupDetail))) {
  client.get(
    path: "/groups/directory",
    query: [
      #("page", Some(int.to_string(page))),
      #("limit", Some(int.to_string(limit))),
    ],
    auth: auth,
    expect: decoders.page(of: decoders.group_detail()),
  )
}

/// `GET /groups/:id/memberships` — who belongs, and in what role.
///
/// Keyed by id rather than handle, unlike the other group calls.
pub fn memberships(
  group_id group_id: String,
  auth auth: Auth,
) -> Promise(ApiResult(Page(Membership))) {
  client.get(
    path: "/groups/" <> group_id <> "/memberships",
    query: [#("limit", Some(int.to_string(200)))],
    auth: auth,
    expect: decoders.page(of: decoders.membership()),
  )
}

/// `GET /tracks?group_id=…`
pub fn tracks(
  group_id group_id: String,
  auth auth: Auth,
) -> Promise(ApiResult(Page(TrackDetail))) {
  client.get(
    path: "/tracks",
    query: [#("group_id", Some(group_id)), #("limit", Some(int.to_string(100)))],
    auth: auth,
    expect: decoders.page(of: decoders.track_detail()),
  )
}
