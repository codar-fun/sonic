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

/// `GET /auth/nonce` — mint a single-use SIWE nonce.
///
/// The nonce must come from the server: it remembers what it minted (with a
/// 15-minute TTL) and rejects any signed message carrying one it did not
/// issue. A locally generated random string looks perfectly well-formed and is
/// answered with "Invalid or expired nonce".
pub fn siwe_nonce() -> Promise(ApiResult(String)) {
  client.get(
    path: "/auth/nonce",
    query: [],
    auth: None,
    expect: {
      use nonce <- decode.field("nonce", decode.string)
      decode.success(nonce)
    },
  )
}

/// `POST /auth/verify_wallet` — Sign-In with Ethereum.
///
/// The message goes up exactly as the wallet signed it. Re-serialising it —
/// normalising a newline, trimming a space — changes the bytes and the
/// signature stops verifying, which is why this takes the raw string rather
/// than the fields it was built from.
pub fn verify_wallet(
  message message: String,
  signature signature: String,
) -> Promise(ApiResult(Session)) {
  client.post(
    path: "/auth/verify_wallet",
    query: [],
    auth: None,
    body: json.object([
      #("message", json.string(message)),
      #("signature", json.string(signature)),
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
