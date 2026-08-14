//// Badge endpoints.
////
//// Two shapes that read alike but answer different questions: a *class* is the
//// template someone defined, a *badge* is one issued instance of it held by an
//// owner. The upstream routes mirror that split, so these do too.

import gleam/int
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
