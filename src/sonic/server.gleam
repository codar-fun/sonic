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
import sonic/api/badge
import sonic/api/event
import sonic/api/group
import sonic/api/profile as profile_api
import sonic/api/types.{
  type ApiError, type Event, type GroupDetail, type Page, DecodeError, HttpError,
  NetworkError,
}
import sonic/router
import sonic/view/layout
import sonic/view/page/badge_detail
import sonic/view/page/communities
import sonic/view/page/discover
import sonic/view/page/error_page
import sonic/view/page/event_detail
import sonic/view/page/event_list
import sonic/view/page/event_share
import sonic/view/page/group_home
import sonic/view/page/group_people
import sonic/view/page/profile
import sonic/view/page/schedule
import sonic/view/page/search
import sonic/view/page/signin
import sonic/view/page/venues
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
    router.EventShare(id), _ -> {
      use result <- promise.map(event.detail(id: id, auth: req.token))
      case result {
        Ok(found) ->
          Page(
            200,
            document_meta(event_share.view(found), signed_in, event_meta(found)),
          )
        Error(err) -> {
          let #(status, message) = explain(err)
          Page(status, document(error_page.view(status, message), signed_in))
        }
      }
    }
    router.EventDetail(id), _ -> {
      use result <- promise.map(event.detail(id: id, auth: req.token))
      case result {
        Ok(found) ->
          Page(
            200,
            document_meta(
              event_detail.view(found),
              signed_in,
              event_meta(found),
            ),
          )
        Error(err) -> {
          let #(status, message) = explain(err)
          Page(status, document(error_page.view(status, message), signed_in))
        }
      }
    }
    router.Communities, _ -> render(communities_page(req.token), signed_in)
    router.Search, _ -> render(search_page(req), signed_in)
    router.BadgeDetail(id), _ -> render(badge_page(id, req.token), signed_in)
    router.BadgeClassDetail(id), _ ->
      render(badge_class_page(id, req.token), signed_in)
    router.GroupHome(handle), _ ->
      render(group_home_page(handle, req.token, tab_of(req)), signed_in)
    router.Schedule(handle), _ ->
      render(
        schedule_page(
          handle,
          req.token,
          "list",
          request.query(req, "start_date"),
          schedule.list_view,
        ),
        signed_in,
      )
    router.ScheduleCompact(handle), _ ->
      render(
        schedule_page(
          handle,
          req.token,
          "compact",
          request.query(req, "start_date"),
          schedule.compact_view,
        ),
        signed_in,
      )
    router.ScheduleVenue(handle), _ ->
      render(
        schedule_page(
          handle,
          req.token,
          "venue",
          request.query(req, "start_date"),
          schedule.venue_view,
        ),
        signed_in,
      )
    router.ScheduleWeek(handle), _ ->
      render(
        schedule_page(
          handle,
          req.token,
          "week",
          request.query(req, "start_date"),
          schedule.week_view,
        ),
        signed_in,
      )
    router.Venues(handle), _ ->
      render(venues_page(handle, req.token), signed_in)
    router.Members(handle), _ ->
      render(
        group_scoped(handle, req.token, fn(found, token) {
          use result <- promise.map(group.memberships(
            group_id: found.id,
            auth: token,
          ))
          result |> map_ok(fn(page) { group_people.members(found, page) })
        }),
        signed_in,
      )
    router.Tracks(handle), _ ->
      render(
        group_scoped(handle, req.token, fn(found, token) {
          use result <- promise.map(group.tracks(
            group_id: found.id,
            auth: token,
          ))
          result |> map_ok(fn(page) { group_people.tracks(found, page) })
        }),
        signed_in,
      )
    router.Profile(handle), _ ->
      render(profile_page(handle, req.token), signed_in)

    router.Signin, Get -> auth_page(200, signin.ask_email(None))
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
    None -> auth_page(400, signin.ask_email(Some("Enter an email address.")))
    Some(email) -> {
      use result <- promise.await(auth.request_email_code(email))
      case result {
        Ok(_) -> auth_page(200, signin.ask_code(email, None))
        Error(err) ->
          auth_page(status_for(err), signin.ask_email(Some(explain(err).1)))
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
      auth_page(400, signin.ask_code(email, Some("Enter the code.")))
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

/// Two requests, run concurrently: the group and its events do not depend on
/// each other, so waiting for them in sequence would double the page's latency
/// for no reason.
/// `upcoming` unless asked otherwise — arriving at a group should show what is
/// coming, not what was missed.
fn tab_of(req: Request) -> String {
  case request.query(req, "tab") {
    Some("past") -> "past"
    _ -> "upcoming"
  }
}

fn group_home_page(
  handle: String,
  token: Option(String),
  tab: String,
) -> Promise(Result(Element(msg), ApiError)) {
  let group = group.detail(handle: handle, auth: token)
  let events =
    group.events(
      handle: handle,
      page: 1,
      limit: 25,
      collection: tab,
      auth: token,
    )

  use group_result <- promise.await(group)
  use events_result <- promise.map(events)

  case group_result, events_result {
    Ok(found), Ok(page) -> Ok(group_home.view(found, page, tab))
    Error(err), _ -> Error(err)
    _, Error(err) -> Error(err)
  }
}

fn communities_page(
  token: Option(String),
) -> Promise(Result(Element(msg), ApiError)) {
  use result <- promise.map(group.directory(page: 1, limit: 100, auth: token))
  result |> map_ok(communities.view)
}

fn badge_page(
  id: String,
  token: Option(String),
) -> Promise(Result(Element(msg), ApiError)) {
  use result <- promise.map(badge.detail(id: id, auth: token))
  result |> map_ok(badge_detail.badge)
}

/// The class and the badges issued from it are independent reads, so they run
/// concurrently rather than in sequence.
fn badge_class_page(
  id: String,
  token: Option(String),
) -> Promise(Result(Element(msg), ApiError)) {
  let class = badge.class(id: id, auth: token)
  let issued = badge.issued_from(class_id: id, page: 1, limit: 30, auth: token)

  use class_result <- promise.await(class)
  use issued_result <- promise.map(issued)

  case class_result, issued_result {
    Ok(found), Ok(page) -> Ok(badge_detail.class(found, page))
    Error(err), _ -> Error(err)
    _, Error(err) -> Error(err)
  }
}

/// Same two concurrent reads as the group home; only the presentation differs.
/// The two fetches are sequential rather than concurrent, unlike the other
/// group pages: the date window is computed in the group's own timezone, so
/// the group has to resolve before the events can be asked for.
fn schedule_page(
  handle: String,
  token: Option(String),
  view: String,
  start_date: Option(String),
  layout: fn(GroupDetail, Option(String), Page(Event)) -> Element(msg),
) -> Promise(Result(Element(msg), ApiError)) {
  use group_result <- promise.await(group.detail(handle: handle, auth: token))

  case group_result {
    Error(err) -> promise.resolve(Error(err))
    Ok(found) -> {
      let zone = option.unwrap(found.timezone, "UTC")
      let anchor = option.unwrap(start_date, "")
      let #(from, to) = schedule_interval(zone, view, anchor)
      use events_result <- promise.map(group.schedule_events(
        handle: handle,
        from: from,
        to: to,
        timezone: found.timezone,
        auth: token,
      ))
      case events_result {
        Ok(page) -> Ok(layout(found, start_date, page))
        Error(err) -> Error(err)
      }
    }
  }
}

@external(javascript, "../sonic_ffi.mjs", "schedule_interval")
fn schedule_interval(
  zone: String,
  view: String,
  start_date: String,
) -> #(String, String)

fn profile_page(
  handle: String,
  token: Option(String),
) -> Promise(Result(Element(msg), ApiError)) {
  use result <- promise.map(profile_api.detail(handle: handle, auth: token))
  result |> map_ok(profile.view)
}

/// Sub-resources are addressed by the group's *id*, not its handle, so the
/// group must resolve before they can be asked for. That sequencing is shared
/// by every group sub-page, so it lives here once.
fn group_scoped(
  handle: String,
  token: Option(String),
  then: fn(GroupDetail, Option(String)) ->
    Promise(Result(Element(msg), ApiError)),
) -> Promise(Result(Element(msg), ApiError)) {
  use group_result <- promise.await(group.detail(handle: handle, auth: token))

  case group_result {
    Error(err) -> promise.resolve(Error(err))
    Ok(found) -> then(found, token)
  }
}

fn venues_page(
  handle: String,
  token: Option(String),
) -> Promise(Result(Element(msg), ApiError)) {
  group_scoped(handle, token, fn(found, token) {
    use venues_result <- promise.map(profile_api.venues(
      group_id: found.id,
      auth: token,
    ))
    venues_result |> map_ok(fn(page) { venues.view(found, page) })
  })
}

fn search_page(req: Request) -> Promise(Result(Element(msg), ApiError)) {
  let keyword = case request.query(req, "keyword") {
    Some(value) -> value
    None -> ""
  }

  case keyword {
    // No keyword is not an error and not a request worth making: render the
    // empty form rather than asking the API about "".
    "" ->
      promise.resolve(Ok(search.view("", types.SearchResults([], [], [], []))))
    _ -> {
      use result <- promise.map(profile_api.search(
        keyword: keyword,
        auth: req.token,
      ))
      result |> map_ok(fn(results) { search.view(keyword, results) })
    }
  }
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

/// Auth pages use the stripped header — showing Discover, search and a Sign In
/// button on the sign-in page itself would be odd, and upstream drops them.
fn auth_page(status: Int, body: Element(msg)) -> Promise(Response) {
  promise.resolve(Page(
    status,
    "<!doctype html>"
      <> element.to_string(layout.auth_document(body, layout.site_meta())),
  ))
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
  document_meta(body, signed_in, layout.site_meta())
}

fn document_meta(
  body: Element(msg),
  signed_in: Bool,
  meta: layout.Meta,
) -> String {
  "<!doctype html>"
  <> element.to_string(layout.document_with(body, signed_in, meta))
}

/// A shared link to an event should preview as that event, not as the site.
fn event_meta(event: Event) -> layout.Meta {
  layout.Meta(
    title: event.title,
    description: case event.content, event.notes {
      Some(text), _ if text != "" -> summarise(text)
      _, Some(text) if text != "" -> summarise(text)
      _, _ -> layout.site_meta().description
    },
    image: case event.cover {
      Some(url) if url != "" -> url
      _ -> layout.site_meta().image
    },
  )
}

/// Previews truncate anyway; sending 290KB of markdown in a meta tag would
/// bloat every page for nothing.
fn summarise(text: String) -> String {
  text
  |> string.replace("\n", " ")
  |> string.slice(0, 200)
}

@external(javascript, "../sonic_ffi.mjs", "serve")
fn serve(
  port: Int,
  handler: fn(String, String, String, String) ->
    Promise(#(Int, String, String, String)),
) -> Nil

@external(javascript, "../sonic_ffi.mjs", "host")
fn host() -> String
