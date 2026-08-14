//// The SSR server.
////
//// Routing and rendering are Gleam; only the socket is JavaScript. A request
//// becomes a `Route`, the route fetches what it needs and returns either a
//// Lustre element or somewhere to redirect to.
////
//// The same view functions run in the browser, so the markup the server sends
//// and the markup the client would build come from one definition rather than
//// two that have to be kept in agreement.

import gleam/int
import gleam/io
import gleam/javascript/promise.{type Promise}
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/element.{type Element}
import sonic/api/auth
import sonic/api/event
import sonic/api/types.{type ApiError, DecodeError, HttpError, NetworkError}
import sonic/router
import sonic/view/layout
import sonic/view/page/discover
import sonic/view/page/error_page
import sonic/view/page/event_detail
import sonic/view/page/event_list
import sonic/view/page/signin
import sonic/web/request.{
  type Request, type Response, ClearSession, Get, Page, Post, Redirect, Request,
}

/// Start listening. The Node event loop keeps the process alive.
///
/// The bind address comes from `SONIC_HOST` and defaults to loopback; in a
/// container it must be `0.0.0.0`, because Traefik reaches containers over the
/// docker network rather than through a published host port.
pub fn start(port port: Int) -> Nil {
  io.println(
    "sonic ssr listening on http://" <> host() <> ":" <> int.to_string(port),
  )
  serve(port, dispatch)
}

/// The FFI boundary: raw strings in, a rendered answer out.
fn dispatch(
  method: String,
  path: String,
  body: String,
  cookies: String,
) -> Promise(#(Int, String, String, String)) {
  let request =
    Request(
      method: case string.uppercase(method) {
        "POST" -> Post
        _ -> Get
      },
      path: path,
      form: request.parse_form(body),
      token: request.token_from_cookies(cookies),
    )

  use response <- promise.map(handle(request))
  encode(response)
}

/// `#(status, html, location, set_cookie)` — empty strings mean "no header".
fn encode(response: Response) -> #(Int, String, String, String) {
  case response {
    Page(status, html) -> #(status, html, "", "")
    Redirect(to, None) -> #(303, "", to, "")
    Redirect(to, Some(token)) -> #(303, "", to, session_cookie(token))
    ClearSession(to) -> #(303, "", to, cleared_cookie())
  }
}

/// HttpOnly so script cannot read it, SameSite=Lax so it survives a normal
/// navigation but not a cross-site POST. Not Secure-flagged here because the
/// dev server is plain HTTP; behind Traefik that is worth revisiting.
fn session_cookie(token: String) -> String {
  request.session_cookie
  <> "="
  <> token
  <> "; Path=/; HttpOnly; SameSite=Lax; Max-Age=2592000"
}

fn cleared_cookie() -> String {
  request.session_cookie <> "=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0"
}

/// Route a request to the handler that answers it.
pub fn handle(req: Request) -> Promise(Response) {
  let signed_in = req.token != None

  case router.parse(req.path), req.method {
    router.Home, _ -> render(home_page(), signed_in)
    router.EventList, _ -> render(event_list_page(req.token), signed_in)
    router.EventDetail(id), _ ->
      render(event_detail_page(id, req.token), signed_in)

    router.Signin, Get -> page(200, signin.ask_email(None), signed_in)
    router.Signin, Post -> start_signin(req)
    router.SigninVerify, Post -> finish_signin(req)
    router.SigninVerify, Get -> promise.resolve(Redirect("/signin", None))

    router.Signout, _ -> promise.resolve(ClearSession("/"))

    // Liveness only: deliberately does not call the API. Tying the health
    // check to an upstream would let an api.sola.day outage make Nomad kill a
    // sonic that is running perfectly well.
    router.Health, _ -> promise.resolve(Page(200, "ok"))

    router.NotFound, _ ->
      page(404, error_page.view(404, "No such page."), signed_in)
  }
}

// --- sign in ---------------------------------------------------------------

fn start_signin(req: Request) -> Promise(Response) {
  case request.field(req, "email") {
    None -> page(400, signin.ask_email(Some("Enter an email address.")), False)
    Some(email) -> {
      use result <- promise.await(auth.request_email_code(email))
      case result {
        Ok(_) -> page(200, signin.ask_code(email, None), False)
        Error(err) ->
          page(status_for(err), signin.ask_email(Some(explain(err).1)), False)
      }
    }
  }
}

fn finish_signin(req: Request) -> Promise(Response) {
  case request.field(req, "email"), request.field(req, "code") {
    Some(email), Some(code) -> {
      use result <- promise.await(auth.verify_email_code(email, code))
      case result {
        Ok(session) -> promise.resolve(Redirect("/", Some(session.token)))
        // A wrong code is a 4xx from upstream, not an outage: keep the visitor
        // on the code step with the address they already typed.
        Error(HttpError(status, _)) if status < 500 ->
          page(
            200,
            signin.ask_code(email, Some("That code didn't work.")),
            False,
          )
        Error(err) ->
          page(
            status_for(err),
            signin.ask_code(email, Some(explain(err).1)),
            False,
          )
      }
    }
    Some(email), None ->
      page(400, signin.ask_code(email, Some("Enter the code.")), False)
    None, _ -> promise.resolve(Redirect("/signin", None))
  }
}

// --- pages -----------------------------------------------------------------

fn home_page() -> Promise(Result(Element(msg), ApiError)) {
  use result <- promise.map(event.discover())
  result |> map_ok(discover.view)
}

fn event_list_page(
  token: Option(String),
) -> Promise(Result(Element(msg), ApiError)) {
  use result <- promise.map(event.first_page(limit: 20, auth: token))
  result |> map_ok(event_list.view)
}

fn event_detail_page(
  id: String,
  token: Option(String),
) -> Promise(Result(Element(msg), ApiError)) {
  use result <- promise.map(event.detail(id: id, auth: token))
  result |> map_ok(event_detail.view)
}

fn render(
  page: Promise(Result(Element(msg), ApiError)),
  signed_in: Bool,
) -> Promise(Response) {
  use result <- promise.map(page)
  case result {
    Ok(body) -> Page(200, document(body, signed_in))
    Error(err) -> {
      let #(status, message) = explain(err)
      Page(status, document(error_page.view(status, message), signed_in))
    }
  }
}

fn page(status: Int, body: Element(msg), signed_in: Bool) -> Promise(Response) {
  promise.resolve(Page(status, document(body, signed_in)))
}

/// What the visitor is told, and under which status.
///
/// An upstream 404 stays a 404; anything else upstream becomes 502, because the
/// failure is ours-to-them, not theirs-to-the-visitor.
fn explain(err: ApiError) -> #(Int, String) {
  case err {
    HttpError(404, _) -> #(404, "That event does not exist.")
    HttpError(401, _) | HttpError(403, _) -> #(403, "That event is not public.")
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

fn status_for(err: ApiError) -> Int {
  explain(err).0
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

fn document(body: Element(msg), signed_in: Bool) -> String {
  "<!doctype html>" <> element.to_string(layout.document(body, signed_in))
}

@external(javascript, "../sonic_ffi.mjs", "serve")
fn serve(
  port: Int,
  handler: fn(String, String, String, String) ->
    Promise(#(Int, String, String, String)),
) -> Nil

@external(javascript, "../sonic_ffi.mjs", "host")
fn host() -> String
