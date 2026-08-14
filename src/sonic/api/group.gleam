//// Group endpoints.
////
//// Groups are addressed by handle in URLs and by id in most payloads; the
//// handle is the `name` field. These take the handle, matching what the router
//// hands over.

import gleam/int
import gleam/javascript/promise.{type Promise}
import gleam/option.{Some}
import sonic/api/client.{type ApiResult, type Auth}
import sonic/api/decoders
import sonic/api/types.{type Event, type GroupDetail, type Page}

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

/// `GET /events?group_handle=…` — that group's events.
pub fn events(
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
