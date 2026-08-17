//// Badge endpoints.
////
//// Two shapes that read alike but answer different questions: a *class* is the
//// template someone defined, a *badge* is one issued instance of it held by an
//// owner. The upstream routes mirror that split, so these do too.

import gleam/int
import gleam/dynamic/decode
import gleam/json
import gleam/javascript/promise.{type Promise}
import gleam/option.{Some}
import sonic/api/client.{type ApiResult, type Auth}
import sonic/api/decoders
import sonic/api/types.{type Badge, type BadgeClass, type Page}

/// `GET /badge_classes/:id`
pub fn class(id id: String, auth auth: Auth) -> Promise(ApiResult(BadgeClass)) {
  client.get(
    path: "/badge_classes/" <> id,
    query: [],
    auth: auth,
    expect: decoders.badge_class(),
  )
}

/// `GET /badges/:id`
pub fn detail(id id: String, auth auth: Auth) -> Promise(ApiResult(Badge)) {
  client.get(
    path: "/badges/" <> id,
    query: [],
    auth: auth,
    expect: decoders.badge(),
  )
}

/// `GET /badges?badge_class_id=…` — every badge issued from one class.
pub fn issued_from(
  class_id class_id: String,
  page page: Int,
  limit limit: Int,
  auth auth: Auth,
) -> Promise(ApiResult(Page(Badge))) {
  client.get(
    path: "/badges",
    query: [
      #("badge_class_id", Some(class_id)),
      #("page", Some(int.to_string(page))),
      #("limit", Some(int.to_string(limit))),
    ],
    auth: auth,
    expect: decoders.page(of: decoders.badge()),
  )
}

/// `POST /vouchers/send_badge` — award a badge to people by handle.
///
/// Receivers are matched by username, wallet address or email, in that order,
/// by the backend. The whole batch is one transaction there: a single bad
/// receiver rolls all of it back, so a partial award cannot happen and the
/// form does not have to reason about one.
pub fn send(
  badge_class_id badge_class_id: String,
  receivers receivers: List(String),
  auth auth: Auth,
) -> Promise(ApiResult(Nil)) {
  client.post(
    path: "/vouchers/send_badge",
    query: [],
    auth: auth,
    body: json.object([
      #("badge_class_id", json.string(badge_class_id)),
      #("receivers", json.array(receivers, json.string)),
    ]),
    expect: decode.success(Nil),
  )
}
