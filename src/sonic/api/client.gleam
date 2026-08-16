//// The single transport for every soon API call.
////
//// One function does the work (`fetch_json`); everything else in `sonic/api`
//// is a thin, typed call site on top of it. Paths are relative to `/api/v1`,
//// matching the server's own routing so call sites read like the API docs.

import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/javascript/promise.{type Promise}
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri
import sonic/api/types.{type ApiError, DecodeError, HttpError, NetworkError}

/// Where the API lives. `soon` is reference-only and never deployed, so this
/// is fixed to the hosted service.
pub const base_url = "https://api.sola.day"

const api_prefix = "/api/v1"

/// A bearer token for endpoints that require a signed-in user.
pub type Auth =
  Option(String)

/// Every API call returns this: the decoded value, or a reason it is absent.
pub type ApiResult(a) =
  Result(a, ApiError)

/// Build the absolute URL for an API path plus query parameters.
///
/// `None` values are dropped rather than serialised as "None", which is the
/// behaviour every call site wants and none should have to remember.
pub fn url(path: String, query: List(#(String, Option(String)))) -> String {
  let query =
    query
    |> list.filter_map(fn(pair) {
      case pair.1 {
        Some(value) -> Ok(#(pair.0, value))
        None -> Error(Nil)
      }
    })

  case query {
    [] -> base_url <> api_prefix <> path
    _ -> base_url <> api_prefix <> path <> "?" <> uri.query_to_string(query)
  }
}

/// GET a path and decode the payload, or explain precisely why not.
pub fn get(
  path path: String,
  query query: List(#(String, Option(String))),
  auth auth: Auth,
  expect decoder: Decoder(a),
) -> Promise(Result(a, ApiError)) {
  send(http.Get, path, query, auth, None, decoder)
}

/// POST a JSON body and decode the payload.
pub fn post(
  path path: String,
  query query: List(#(String, Option(String))),
  auth auth: Auth,
  body body: json.Json,
  expect decoder: Decoder(a),
) -> Promise(Result(a, ApiError)) {
  send(http.Post, path, query, auth, Some(body), decoder)
}

/// PATCH a JSON body. Used for partial updates, where sending the whole
/// record back would overwrite fields this client does not model.
pub fn patch(
  path path: String,
  query query: List(#(String, Option(String))),
  auth auth: Auth,
  body body: json.Json,
  expect decoder: Decoder(a),
) -> Promise(Result(a, ApiError)) {
  send(http.Patch, path, query, auth, Some(body), decoder)
}

fn send(
  method: http.Method,
  path: String,
  query: List(#(String, Option(String))),
  auth: Auth,
  body: Option(json.Json),
  decoder: Decoder(a),
) -> Promise(Result(a, ApiError)) {
  let assert Ok(req) = request.to(url(path, query))

  let req =
    req
    |> request.set_method(method)
    |> request.set_header("accept", "application/json")
    |> with_auth(auth)
    |> with_body(body)

  use result <- promise.map(do_fetch(req))

  use res <- result.try(result)
  case res.status {
    status if status >= 200 && status < 300 ->
      json.parse(res.body, decoder)
      |> result.map_error(fn(e) { DecodeError(string.inspect(e)) })
    status -> Error(HttpError(status, res.body))
  }
}

fn with_auth(
  req: request.Request(String),
  auth: Auth,
) -> request.Request(String) {
  case auth {
    Some(token) -> request.set_header(req, "authorization", "Bearer " <> token)
    None -> req
  }
}

fn with_body(
  req: request.Request(String),
  body: Option(json.Json),
) -> request.Request(String) {
  case body {
    Some(json_body) ->
      req
      |> request.set_header("content-type", "application/json")
      |> request.set_body(json.to_string(json_body))
    None -> request.set_body(req, "")
  }
}

/// The one place that touches the platform. Implemented in JS because `fetch`
/// is the host's, not Gleam's — this is the "necessary part" the brief allows.
@external(javascript, "../../sonic_ffi.mjs", "fetch_text")
fn fetch_text(
  method: String,
  url: String,
  headers: List(#(String, String)),
  body: String,
) -> Promise(Result(#(Int, String), String))

fn do_fetch(
  req: request.Request(String),
) -> Promise(Result(response.Response(String), ApiError)) {
  let method = case req.method {
    http.Post -> "POST"
    http.Put -> "PUT"
    http.Patch -> "PATCH"
    http.Delete -> "DELETE"
    _ -> "GET"
  }

  use result <- promise.map(fetch_text(
    method,
    request.to_uri(req) |> uri.to_string,
    req.headers,
    req.body,
  ))

  case result {
    Ok(#(status, body)) ->
      Ok(response.Response(status: status, headers: [], body: body))
    Error(detail) -> Error(NetworkError(detail))
  }
}
