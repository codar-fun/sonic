//// Sign-in.
////
//// soon issues a one-time code to an address, then trades that code for a JWT.
//// An unknown address signs *up* on verify, so there is no separate register
//// call — which is why the result carries `name`, and a null name means the
//// account exists but has not chosen a username yet.

import gleam/dynamic/decode.{type Decoder}
import gleam/javascript/promise.{type Promise}
import gleam/json
import gleam/option.{type Option, None}
import sonic/api/client.{type ApiResult}
import sonic/api/types.{type Session, type User, Session, User}

/// `POST /auth/request_code` — send a one-time code to an email address.
///
/// Returns nothing useful on success: the server deliberately answers the same
/// way whether or not the address is already registered, so this cannot be used
/// to enumerate accounts.
pub fn request_email_code(email email: String) -> Promise(ApiResult(Nil)) {
  client.post(
    path: "/auth/request_code",
    query: [],
    auth: None,
    body: json.object([#("email", json.string(email))]),
    expect: decode.success(Nil),
  )
}

/// `POST /auth/verify_code` — trade a code for a session.
pub fn verify_email_code(
  email email: String,
  code code: String,
) -> Promise(ApiResult(Session)) {
  client.post(
    path: "/auth/verify_code",
    query: [],
    auth: None,
    body: json.object([
      #("email", json.string(email)),
      #("code", json.string(code)),
    ]),
    expect: session(),
  )
}

fn session() -> Decoder(Session) {
  use token <- decode.field("token", decode.string)
  use user <- decode.field("user", user())
  decode.success(Session(token:, user:))
}

fn user() -> Decoder(User) {
  use id <- decode.field("id", decode.string)
  use email <- decode.optional_field(
    "email",
    None,
    decode.optional(decode.string),
  )
  use name <- decode.optional_field(
    "name",
    None,
    decode.optional(decode.string),
  )
  decode.success(User(id:, email:, name:))
}

/// An account that has not chosen a username yet. The upstream app routes these
/// through /register rather than treating them as fully signed in.
pub fn needs_username(user: User) -> Bool {
  case user.name {
    None -> True
    option.Some("") -> True
    option.Some(_) -> False
  }
}

/// The name to greet someone by, falling back to their address.
pub fn display_name(user: User) -> Option(String) {
  case user.name, user.email {
    option.Some(name), _ if name != "" -> option.Some(name)
    _, email -> email
  }
}
