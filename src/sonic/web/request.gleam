//// What a page handler is given, and what it may answer with.
////
//// Kept deliberately small: a path, a method, form fields, and whatever
//// session the cookie carried. Anything a handler cannot get from this it is
//// not supposed to know.

import gleam/list
import gleam/result
import sonic/i18n.{type Lang}
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/uri

pub type Method {
  Get
  Post
}

pub type Request {
  Request(
    method: Method,
    path: String,
    /// Decoded `application/x-www-form-urlencoded` fields, empty on GET.
    form: List(#(String, String)),
    /// The bearer token from the session cookie, if one was sent.
    token: Option(String),
    /// The language to render in, from the `lang` cookie.
    lang: Lang,
  )
}

/// How a handler answers: a page to render, or somewhere else to go.
///
/// Redirect exists so POST handlers can follow post/redirect/get instead of
/// rendering a page the browser would re-submit on refresh.
pub type Response {
  Page(status: Int, html: String)
  Redirect(to: String, set_session: Option(String))
  ClearSession(to: String)
  /// Write the language cookie and go back where the switch was made.
  SetLanguage(code: String, to: String)
}

/// The cookie the session token travels in. `auth_token` matches the upstream
/// app's default (`NEXT_PUBLIC_AUTH_FIELD`), so a browser signed in to either
/// app is signed in to both during the migration.
pub const session_cookie = "auth_token"

/// Read a query-string parameter from the request path.
///
/// Query parameters are parsed on demand rather than eagerly: only the search
/// page reads one, and parsing every request's query to serve one route would
/// be work done for nothing.
pub fn query(request: Request, name: String) -> Option(String) {
  case string.split_once(request.path, "?") {
    Ok(#(_, rest)) ->
      case list.key_find(parse_form(rest), name) {
        Ok("") -> None
        Ok(value) -> Some(value)
        Error(_) -> None
      }
    Error(_) -> None
  }
}

/// Read one field from a decoded form.
pub fn field(request: Request, name: String) -> Option(String) {
  case list.key_find(request.form, name) {
    Ok("") -> None
    Ok(value) -> Some(value)
    Error(_) -> None
  }
}

/// Parse `application/x-www-form-urlencoded` into pairs.
///
/// `+` means space in form encoding but not in URI percent-decoding, so it is
/// substituted before decoding rather than after — otherwise an address like
/// `a+b@example.com` would survive as a literal plus in one place and a space
/// in another.
pub fn parse_form(body: String) -> List(#(String, String)) {
  body
  |> string.split("&")
  |> list.filter_map(fn(pair) {
    case string.split_once(pair, "=") {
      Ok(#(key, value)) ->
        case decode_component(key), decode_component(value) {
          Ok(key), Ok(value) -> Ok(#(key, value))
          _, _ -> Error(Nil)
        }
      Error(_) -> Error(Nil)
    }
  })
}

fn decode_component(value: String) -> Result(String, Nil) {
  value |> string.replace("+", " ") |> uri.percent_decode
}

/// Pull the session token out of a `Cookie:` header.
pub fn token_from_cookies(header: String) -> Option(String) {
  header
  |> string.split(";")
  |> list.filter_map(fn(pair) {
    case string.split_once(string.trim(pair), "=") {
      Ok(#(name, value)) if name == session_cookie -> Ok(value)
      _ -> Error(Nil)
    }
  })
  |> list.first
  |> option.from_result
}

/// The chosen language, from the `lang` cookie. Absent means English, which
/// is also what an unrecognised value means — a bad cookie should not blank
/// the site.
pub fn lang_from_cookies(header: String) -> String {
  header
  |> string.split(";")
  |> list.filter_map(fn(pair) {
    case string.split_once(string.trim(pair), "=") {
      Ok(#(name, value)) if name == "lang" -> Ok(value)
      _ -> Error(Nil)
    }
  })
  |> list.first
  |> result.unwrap("en")
}
