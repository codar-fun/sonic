//// The SSR server.
////
//// Routing and rendering are Gleam; only the socket is JavaScript. A request
//// becomes a `Route`, the route fetches what it needs and returns a Lustre
//// element, and that element is serialised with `element.to_string`.
////
//// The same view functions run in the browser, so the markup the server sends
//// and the markup the client would build come from one definition rather than
//// two that have to be kept in agreement.

import gleam/int
import gleam/io
import gleam/javascript/promise.{type Promise}
import gleam/option.{None}
import gleam/string
import lustre/element.{type Element}
import sonic/api/types.{
  type ApiError, DecodeError, HttpError, NetworkError,
}
import sonic/api/event
import sonic/router
import sonic/view/layout
import sonic/view/page/event_detail
import sonic/view/page/event_list
import sonic/view/page/error_page

/// Start listening. The Node event loop keeps the process alive.
///
/// The bind address comes from `SONIC_HOST` and defaults to loopback; in a
/// container it must be `0.0.0.0`, because Traefik reaches containers over the
/// docker network rather than through a published host port.
pub fn start(port port: Int) -> Nil {
  io.println(
    "sonic ssr listening on http://" <> host() <> ":" <> int.to_string(port),
  )
  serve(port, handle)
}

/// Turn a request path into a status and an HTML document.
///
/// A promise because most routes need the API before they can render; the
/// server FFI awaits it.
pub fn handle(path: String) -> Promise(#(Int, String)) {
  case router.parse(path) {
    router.EventList -> render(event_list_page())
    router.EventDetail(id) -> render(event_detail_page(id))
    router.NotFound ->
      promise.resolve(#(404, document(error_page.view(404, "No such page."))))
  }
}

fn event_list_page() -> Promise(Result(Element(msg), ApiError)) {
  use result <- promise.map(event.first_page(limit: 20, auth: None))
  result |> map_ok(event_list.view)
}

fn event_detail_page(id: String) -> Promise(Result(Element(msg), ApiError)) {
  use result <- promise.map(event.detail(id: id, auth: None))
  result |> map_ok(event_detail.view)
}

/// Render a page, turning an API failure into the page a visitor should see
/// instead of a stack trace.
fn render(page: Promise(Result(Element(msg), ApiError))) -> Promise(#(Int, String)) {
  use result <- promise.map(page)
  case result {
    Ok(body) -> #(200, document(body))
    Error(err) -> {
      let #(status, message) = explain(err)
      #(status, document(error_page.view(status, message)))
    }
  }
}

/// What the visitor is told, and under which status.
///
/// An upstream 404 stays a 404; anything else upstream becomes 502, because
/// the failure is ours-to-them, not theirs-to-the-visitor.
fn explain(err: ApiError) -> #(Int, String) {
  case err {
    HttpError(404, _) -> #(404, "That event does not exist.")
    HttpError(401, _) | HttpError(403, _) -> #(
      403,
      "That event is not public.",
    )
    HttpError(status, body) -> #(
      502,
      "Upstream returned "
        <> int.to_string(status)
        <> ": "
        <> string.slice(body, 0, 200),
    )
    DecodeError(detail) -> #(
      502,
      "The API returned a shape sonic does not understand: " <> detail,
    )
    NetworkError(detail) -> #(502, "Could not reach the API: " <> detail)
  }
}

fn map_ok(
  result: Result(a, ApiError),
  with view: fn(a) -> Element(msg),
) -> Result(Element(msg), ApiError) {
  case result {
    Ok(value) -> Ok(view(value))
    Error(err) -> Error(err)
  }
}

fn document(body: Element(msg)) -> String {
  "<!doctype html>" <> element.to_string(layout.document(body))
}

@external(javascript, "../sonic_ffi.mjs", "serve")
fn serve(port: Int, handler: fn(String) -> Promise(#(Int, String))) -> Nil

@external(javascript, "../sonic_ffi.mjs", "host")
fn host() -> String
