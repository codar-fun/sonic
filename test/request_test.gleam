//// Form decoding and cookie reading. Both parse attacker-reachable input, so
//// the cases that matter are the malformed ones.

import gleam/option.{None, Some}
import gleeunit/should
import sonic/web/request

pub fn parses_simple_form_test() {
  request.parse_form("email=a%40b.com&code=123456")
  |> should.equal([#("email", "a@b.com"), #("code", "123456")])
}

/// `+` means space in form encoding, but a literal `+` in an address arrives
/// as `%2B`. Both must survive, and they are decoded by different rules.
pub fn plus_handling_test() {
  request.parse_form("email=jose%2Bsonic%40sola.day")
  |> should.equal([#("email", "jose+sonic@sola.day")])

  request.parse_form("name=John+Smith")
  |> should.equal([#("name", "John Smith")])
}

pub fn empty_body_is_no_fields_test() {
  request.parse_form("") |> should.equal([])
}

/// A pair with no `=` is dropped rather than becoming a key with an empty
/// value, so `field` cannot report a field the client never sent.
pub fn malformed_pairs_are_dropped_test() {
  request.parse_form("novalue&a=1") |> should.equal([#("a", "1")])
}

pub fn empty_value_is_kept_as_empty_test() {
  request.parse_form("email=") |> should.equal([#("email", "")])
}

pub fn field_treats_empty_as_absent_test() {
  let req =
    request.Request(
      method: request.Post,
      path: "/signin",
      form: [#("email", ""), #("code", "9")],
      token: None,
    )
  request.field(req, "email") |> should.equal(None)
  request.field(req, "code") |> should.equal(Some("9"))
  request.field(req, "missing") |> should.equal(None)
}

pub fn reads_session_cookie_test() {
  request.token_from_cookies("auth_token=abc123")
  |> should.equal(Some("abc123"))
}

pub fn finds_the_cookie_among_others_test() {
  request.token_from_cookies("lang=en; auth_token=abc123; theme=dark")
  |> should.equal(Some("abc123"))
}

pub fn no_cookie_header_is_no_token_test() {
  request.token_from_cookies("") |> should.equal(None)
  request.token_from_cookies("lang=en; theme=dark") |> should.equal(None)
}

/// A cookie whose name merely ends with the session name must not match —
/// otherwise `not_auth_token=x` would be read as a session.
pub fn similar_cookie_names_do_not_match_test() {
  request.token_from_cookies("not_auth_token=evil") |> should.equal(None)
  request.token_from_cookies("auth_token_x=evil") |> should.equal(None)
}

/// The search page reads its keyword from the query string, so this is the
/// path where a wrong answer silently returns "no results".
pub fn reads_query_parameters_test() {
  let req = fn(path) {
    request.Request(method: request.Get, path: path, form: [], token: None)
  }
  request.query(req("/search?keyword=eth"), "keyword")
  |> should.equal(Some("eth"))

  request.query(req("/search?a=1&keyword=zuzalu&b=2"), "keyword")
  |> should.equal(Some("zuzalu"))

  // Encoded values must decode, or a two-word search finds nothing.
  request.query(req("/search?keyword=hello%20world"), "keyword")
  |> should.equal(Some("hello world"))

  request.query(req("/search"), "keyword") |> should.equal(None)
  request.query(req("/search?keyword="), "keyword") |> should.equal(None)
}
