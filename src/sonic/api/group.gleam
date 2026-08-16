//// Group endpoints.
////
//// Groups are addressed by handle in URLs and by id in most payloads; the
//// handle is the `name` field. These take the handle, matching what the router
//// hands over.

import gleam/int
import gleam/json
import gleam/list
import gleam/javascript/promise.{type Promise}
import gleam/option.{type Option, None, Some}
import gleam/string
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
  tags tags: List(String),
  auth auth: Auth,
) -> Promise(ApiResult(Page(Event))) {
  client.get(
    path: "/events",
    query: [
      #("group_id", Some(handle)),
      #("start_date", Some(from)),
      #("end_date", Some(to)),
      #("timezone", timezone),
      // Comma-joined, as upstream sends it. Empty means no tag filter at all,
      // which is different from "match nothing".
      #("tags", case tags {
        [] -> None
        values -> Some(string.join(values, ","))
      }),
      #("limit", Some("400")),
    ],
    auth: auth,
    expect: decoders.page(of: decoders.event()),
  )
}

/// `POST /groups` — create a group with this handle.
pub fn create(
  name name: String,
  auth auth: Auth,
) -> Promise(ApiResult(GroupDetail)) {
  client.post(
    path: "/groups",
    query: [],
    auth: auth,
    body: json.object([#("group", json.object([#("name", json.string(name))]))]),
    expect: decoders.group_detail(),
  )
}

/// The handle rules, checked before the request rather than after.
///
/// Ported from upstream's `verifyUsername`: lowercase letters and digits,
/// single hyphens between them but never at either end, 6 to 20 characters.
/// The name becomes the group's URL and cannot be changed, so rejecting it
/// here is kinder than a 422 from the server.
pub fn invalid_name(name: String) -> Option(String) {
  let length = string.length(name)
  case name {
    "" -> Some("Please input a group name")
    _ ->
      case
        string.starts_with(name, "-"),
        string.ends_with(name, "-"),
        length < 6,
        length > 20,
        is_allowed(name)
      {
        True, _, _, _, _ -> Some("Group name cannot start with \"-\"")
        _, True, _, _, _ -> Some("Group name cannot end with \"-\"")
        _, _, True, _, _ -> Some("The minimum length of a group name is 6")
        _, _, _, True, _ -> Some("The maximum length of a group name is 20")
        _, _, _, _, False ->
          Some("Group name contains an invalid character")
        _, _, _, _, True -> None
      }
  }
}

/// a-z, 0-9 and single hyphens between them.
fn is_allowed(name: String) -> Bool {
  let chars = string.to_graphemes(name)
  let allowed =
    list.all(chars, fn(c) {
      string.contains("abcdefghijklmnopqrstuvwxyz0123456789-", c)
    })
  allowed && !string.contains(name, "--")
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
