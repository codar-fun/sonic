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
import gleam/list
import gleam/io
import gleam/javascript/promise.{type Promise}
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/element.{type Element}
import sonic/api/auth
import sonic/i18n.{type Lang}
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
import sonic/view/page/event_create
import sonic/view/page/event_detail
import sonic/view/page/event_list
import sonic/view/page/event_share
import sonic/view/page/group_create
import sonic/view/page/group_forms
import sonic/view/page/group_home
import sonic/view/page/group_people
import sonic/view/page/popup_cities
import sonic/view/page/register
import sonic/view/page/profile
import sonic/view/page/profile_edit
import sonic/view/page/schedule
import sonic/view/page/search
import sonic/view/page/signin
import sonic/view/page/venues
import sonic/web/request.{
  type Request, type Response, ClearSession, Get, Page, Post, Redirect, Request,
  SetLanguage,
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
      lang: i18n.parse(request.lang_from_cookies(cookies)),
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
    SetLanguage(code, to) -> #(303, "", to, language_cookie(code))
  }
}

/// HttpOnly so script cannot read it, SameSite=Lax so it survives a normal
/// navigation but not a cross-site POST, and Secure so it is never sent in
/// clear.
///
/// Secure is a flag rather than unconditional because the dev server is plain
/// HTTP and a Secure cookie there would simply never come back, making local
/// sign-in look broken. It is set in the container, where the only way in is
/// HTTPS through Traefik.
fn session_cookie(token: String) -> String {
  request.session_cookie
  <> "="
  <> token
  <> "; Path=/; HttpOnly; SameSite=Lax; Max-Age=2592000"
  <> secure_flag()
}

/// Not HttpOnly: the choice is not a secret and the client may want to read
/// it. A year, because a language preference does not expire meaningfully.
fn language_cookie(code: String) -> String {
  "lang=" <> code <> "; Path=/; SameSite=Lax; Max-Age=31536000" <> secure_flag()
}

fn cleared_cookie() -> String {
  request.session_cookie
  <> "=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0"
  <> secure_flag()
}

fn secure_flag() -> String {
  case secure_cookies() {
    True -> "; Secure"
    False -> ""
  }
}

/// What every rendered page needs to know about the request it answers.
///
/// This replaced a bare `signed_in: Bool` threaded through the same call
/// sites. Adding language and path as two more parameters would have meant
/// touching fifty-odd calls; carrying one value means the next thing a page
/// needs about its request is a field, not another parameter.
pub type Ctx {
  Ctx(signed_in: Bool, lang: i18n.Lang, path: String)
}

fn ctx_of(req: Request) -> Ctx {
  Ctx(signed_in: req.token != None, lang: req.lang, path: req.path)
}

/// Route a request to the handler that answers it.
pub fn handle(req: Request) -> Promise(Response) {
  let signed_in = req.token != None
  let ctx = ctx_of(req)

  case router.parse(req.path), req.method {
    router.Home, _ -> render(home_page(ctx.lang), ctx)
    router.EventShare(id), _ -> {
      use result <- promise.map(event.detail(id: id, auth: req.token))
      case result {
        Ok(found) ->
          Page(
            200,
            document_meta(event_share.view(found), ctx, event_meta(found)),
          )
        Error(err) -> {
          let #(status, message) = explain(err)
          Page(status, document(error_page.view(status, message), ctx))
        }
      }
    }
    router.EventDetail(id), _ -> {
      use result <- promise.await(event.detail(id: id, auth: req.token))
      case result {
        Ok(found) -> {
          let tab = case request.query(req, "tab") {
            Some("participants") -> "participants"
            _ -> "content"
          }
          use repeats <- promise.await(recurrence_of(found))
          // Only fetched for the tab that shows them; the content tab would
          // pay for a request it never renders.
          // Whether the caller is on the attendee list decides which control
          // the panel shows, so it is asked for even on the content tab.
          use attending <- promise.await(case req.token {
            Some(_) -> event.is_attending(id: id, auth: req.token)
            None -> promise.resolve(False)
          })
          use talk <- promise.await(
            promise.map(event.comments(id: id), fn(result) {
              case result {
                Ok(page) -> page.data
                Error(_) -> []
              }
            }),
          )
          use people <- promise.map(case tab {
            "participants" ->
              promise.map(event.participants(id: id), fn(result) {
                case result {
                  Ok(page) -> page.data
                  Error(_) -> []
                }
              })
            _ -> promise.resolve([])
          })
          Page(
            200,
            document_meta(
              event_detail.view(
                found,
                repeats,
                signed_in,
                tab,
                people,
                talk,
                attending,
                ctx.lang,
              ),
              ctx,
              event_meta(found),
            ),
          )
        }
        Error(err) -> {
          let #(status, message) = explain(err)
          promise.resolve(Page(
            status,
            document(error_page.view(status, message), ctx),
          ))
        }
      }
    }
    router.EventComment(id), Post -> post_comment(id, req)
    router.EventAttend(id), Post -> attend_event(id, req)
    router.EventAttend(id), Get ->
      promise.resolve(Redirect("/event/detail/" <> id, None))
    router.EventComment(id), Get ->
      promise.resolve(Redirect("/event/detail/" <> id, None))

    // The home page has linked here since it was built; the route did not
    // exist, so that link was a 404 on the front page.
    router.PopupCities, _ -> render(popup_cities_page(ctx.lang), ctx)
    router.GroupSetting(handle), Get -> group_form(handle, req, "setting", None)
    router.GroupSetting(handle), Post -> save_group_setting(handle, req)
    router.VenueCreate(handle), Get -> group_form(handle, req, "venue", None)
    router.VenueCreate(handle), Post -> save_venue(handle, req)
    router.TrackCreate(handle), Get -> group_form(handle, req, "track", None)
    router.TrackCreate(handle), Post -> save_track(handle, req)
    router.EventCreate(handle), Get -> event_create_page(handle, req, None)
    router.EventCreate(handle), Post -> create_event(handle, req)
    router.Register, Get -> register_page(req, "", None)
    router.Register, Post -> save_username(req)
    router.GroupCreate, Get -> group_create_page(req, "", None)
    router.GroupCreate, Post -> create_group(req)

    router.Communities, _ -> render(communities_page(req.token, ctx.lang), ctx)
    router.Search, _ -> render(search_page(req), ctx)
    // Upstream's URL for "the events I am going to". There is no separate page
    // for it here — the profile already has that list — so this resolves the
    // signed-in handle and sends them to their own.
    router.MyEvents, _ -> my_events(req)
    // Writes the choice and returns where it was made, so switching language
    // keeps you on the page you were reading.
    router.SetLanguage, _ ->
      promise.resolve(SetLanguage(
        // Normalised through the Lang type, so only a language this build
        // knows can reach the cookie. `safe_return` guards the destination,
        // which is a path — it is not a validator for the code itself, and
        // using it here made every switch write "en".
        i18n.code(i18n.parse(option.unwrap(request.query(req, "to"), "en"))),
        option.unwrap(safe_return(request.query(req, "return")), "/"),
      ))
    router.BadgeDetail(id), _ -> render(badge_page(id, req.token), ctx)
    router.BadgeClassDetail(id), _ ->
      render(badge_class_page(id, req.token), ctx)
    router.GroupHome(handle), _ ->
      render(
        group_home_page(handle, req.token, tab_of(req), signed_in),
        ctx,
      )
    router.Schedule(handle), _ ->
      render(
        schedule_page(
          handle,
          req.token,
          "list",
          request.query(req, "start_date"),
          request.query(req, "tags"),
          schedule.list_view,
        ),
        ctx,
      )
    router.ScheduleCompact(handle), _ ->
      render(
        schedule_page(
          handle,
          req.token,
          "compact",
          request.query(req, "start_date"),
          request.query(req, "tags"),
          schedule.compact_view,
        ),
        ctx,
      )
    router.ScheduleVenue(handle), _ ->
      render(
        schedule_page(
          handle,
          req.token,
          "venue",
          request.query(req, "start_date"),
          request.query(req, "tags"),
          schedule.venue_view,
        ),
        ctx,
      )
    router.ScheduleWeek(handle), _ ->
      render(
        schedule_page(
          handle,
          req.token,
          "week",
          request.query(req, "start_date"),
          request.query(req, "tags"),
          schedule.week_view,
        ),
        ctx,
      )
    router.Venues(handle), _ ->
      render(
        group_scoped(handle, req.token, fn(found, _token) {
          promise.resolve(Ok(venues.view(found, ctx.lang)))
        }),
        ctx,
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
        ctx,
      )
    router.ProfileEdit(handle), Get -> profile_edit_page(handle, req)
    router.ProfileEdit(handle), Post -> save_profile(handle, req)

    router.Profile(handle), _ ->
      render(profile_page(handle, req.token, req), ctx)

    // Already signed in: the form would be a dead end, so send them where
    // they were going instead.
    router.Signin, Get if signed_in ->
      promise.resolve(Redirect(
        option.unwrap(safe_return(request.query(req, "return")), "/"),
        None,
      ))
    router.Signin, Get ->
      auth_page(
        200,
        signin.ask_email(
          None,
          safe_return(request.query(req, "return")),
          ctx.lang,
        ),
        ctx,
      )
    router.Signin, Post -> start_signin(req)
    router.SigninVerify, Post -> finish_signin(req)
    router.SigninWallet, Post -> finish_wallet_signin(req)
    // Minted per attempt rather than rendered into every sign-in page: the
    // nonce is single-use with a 15-minute life, and most visitors here are
    // signing in by email and would never spend it.
    router.SigninNonce, _ -> {
      use result <- promise.map(auth.siwe_nonce())
      case result {
        Ok(nonce) -> Page(200, nonce)
        Error(err) -> Page(status_for(err), "")
      }
    }
    // Nothing to show: the wallet route only exists to receive a signature.
    router.SigninWallet, Get -> promise.resolve(Redirect("/signin", None))
    router.SigninVerify, Get -> promise.resolve(Redirect("/signin", None))

    router.Signout, _ -> promise.resolve(ClearSession("/"))

    // Liveness only: deliberately does not call the API. Tying the health
    // check to an upstream would let an api.sola.day outage make Nomad kill a
    // sonic that is running perfectly well.
    router.Health, _ -> promise.resolve(Page(200, "ok"))

    router.NotFound, _ ->
      page(404, error_page.view(404, "No such page."), ctx)
  }
}

// --- sign in ---------------------------------------------------------------

fn start_signin(req: Request) -> Promise(Response) {
  let ctx = ctx_of(req)
  let back = safe_return(request.field(req, "return"))
  case request.field(req, "email") {
    None -> auth_page(400, signin.ask_email(Some("Enter an email address."), back, ctx.lang), ctx)
    Some(email) -> {
      use result <- promise.await(auth.request_email_code(email))
      case result {
        Ok(_) -> auth_page(200, signin.ask_code(email, None, back, ctx.lang), ctx)
        Error(err) ->
          auth_page(status_for(err), signin.ask_email(Some(explain(err).1), back, ctx.lang), ctx)
      }
    }
  }
}

fn finish_signin(req: Request) -> Promise(Response) {
  let ctx = ctx_of(req)
  case request.field(req, "email"), request.field(req, "code") {
    Some(email), Some(code) -> {
      use result <- promise.await(auth.verify_email_code(email, code))
      let back =
        option.unwrap(safe_return(request.field(req, "return")), "/")
      case result {
        Ok(session) -> promise.resolve(Redirect(back, Some(session.token)))
        // A wrong code is a 4xx from upstream, not an outage: keep the visitor
        // on the code step with the address they already typed.
        Error(HttpError(status, _)) if status < 500 ->
          page(
            200,
            signin.ask_code(
              email,
              Some("That code didn't work."),
              safe_return(request.field(req, "return")),
              ctx.lang,
            ),
            ctx,
          )
        Error(err) ->
          page(
            status_for(err),
            signin.ask_code(
              email,
              Some(explain(err).1),
              safe_return(request.field(req, "return")),
              ctx.lang,
            ),
            ctx,
          )
      }
    }
    Some(email), None ->
      auth_page(
        400,
        signin.ask_code(
          email,
          Some("Enter the code."),
          safe_return(request.field(req, "return")),
          ctx.lang,
        ),
        ctx,
      )
    None, _ -> promise.resolve(Redirect("/signin", None))
  }
}

// --- pages -----------------------------------------------------------------

fn home_page(lang: Lang) -> Promise(Result(Element(msg), ApiError)) {
  use result <- promise.map(event.discover())
  result |> map_ok(fn(data) { discover.view(data, lang) })
}

fn event_list_page(
  token: Option(String),
) -> Promise(Result(Element(msg), ApiError)) {
  use result <- promise.map(event.first_page(limit: 20, auth: token))
  result |> map_ok(event_list.view)
}

/// The recurrence interval is a second request, and only when the event is
/// part of a series — most are not, and asking unconditionally would put an
/// extra round trip on every event page to render nothing.
///
/// A failure there is swallowed: the series label is a detail, and losing the
/// whole page because a secondary lookup failed would be the wrong trade.
fn recurrence_of(event_detail: Event) -> Promise(Option(String)) {
  case event_detail.recurring_id {
    Some(id) if id != "" ->
      promise.map(event.recurring_interval(id: id), fn(result) {
        case result {
          Ok(interval) if interval != "" -> Some(interval)
          _ -> None
        }
      })
    _ -> promise.resolve(None)
  }
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
  signed_in: Bool,
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
    Ok(found), Ok(page) -> Ok(group_home.view(found, page, tab, signed_in))
    Error(err), _ -> Error(err)
    _, Error(err) -> Error(err)
  }
}

fn popup_cities_page(
  lang: Lang,
) -> Promise(Result(Element(msg), ApiError)) {
  use result <- promise.map(event.discover())
  result
  |> map_ok(fn(data) { popup_cities.view(data.popup_cities, lang) })
}

fn communities_page(
  token: Option(String),
  lang: Lang,
) -> Promise(Result(Element(msg), ApiError)) {
  use result <- promise.map(group.all_directory(auth: token))
  result |> map_ok(fn(page) { communities.view(page, lang) })
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
  selected_tags: Option(String),
  layout:
    fn(GroupDetail, Option(String), List(String), Page(Event)) -> Element(msg),
) -> Promise(Result(Element(msg), ApiError)) {
  use group_result <- promise.await(group.detail(handle: handle, auth: token))

  case group_result {
    Error(err) -> promise.resolve(Error(err))
    Ok(found) -> {
      let zone = option.unwrap(found.timezone, "UTC")
      let anchor = option.unwrap(start_date, "")
      // Sent comma-joined by the filter form and by upstream's own links, so
      // both shapes have to parse.
      let tags = case option.unwrap(selected_tags, "") {
        "" -> []
        value -> string.split(value, ",")
      }
      let #(from, to) = schedule_interval(zone, view, anchor)
      use events_result <- promise.map(group.schedule_events(
        handle: handle,
        from: from,
        to: to,
        timezone: found.timezone,
        tags: tags,
        auth: token,
      ))
      case events_result {
        Ok(page) -> Ok(layout(found, start_date, tags, page))
        Error(err) -> Error(err)
      }
    }
  }
}

@external(javascript, "../sonic_ffi.mjs", "secure_cookies")
fn secure_cookies() -> Bool

@external(javascript, "../sonic_ffi.mjs", "schedule_interval")
fn schedule_interval(
  zone: String,
  view: String,
  start_date: String,
) -> #(String, String)

/// Only the selected tab's data is fetched. The profile carries four event
/// lists, its groups and its badges; loading all six for a page that shows one
/// would be six requests to render one.
fn profile_page(
  handle: String,
  token: Option(String),
  req: Request,
) -> Promise(Result(Element(msg), ApiError)) {
  let tab = case request.query(req, "tab") {
    Some("groups") -> profile.Groups
    Some("badges") ->
      profile.Badges(case request.query(req, "list") {
        Some("created") -> "created"
        _ -> "collected"
      })
    _ ->
      profile.Events(case request.query(req, "list") {
        Some("hosting") -> "hosting"
        Some("co-hosting") -> "co-hosting"
        Some("starred") -> "starred"
        _ -> "attending"
      })
  }

  use result <- promise.await(profile_api.detail(handle: handle, auth: token))
  case result {
    Error(err) -> promise.resolve(Error(err))
    Ok(user) ->
      case tab {
        profile.Events(which) -> {
          use events <- promise.map(profile_api.events(
            filter: event_filter(which),
            handle: handle,
            auth: token,
          ))
          Ok(profile.view(user, tab, page_or_empty(events), [], []))
        }
        profile.Groups -> {
          use groups <- promise.map(profile_api.groups(
            handle: handle,
            auth: token,
          ))
          Ok(profile.view(user, tab, [], list_or_empty(groups), []))
        }
        profile.Badges("created") -> {
          use classes <- promise.map(profile_api.badge_classes(
            handle: handle,
            auth: token,
          ))
          Ok(profile.view(
            user,
            tab,
            [],
            [],
            list.map(page_or_empty(classes), fn(entry) {
              #(
                "/badge-class/" <> entry.id,
                option.unwrap(entry.image_url, ""),
                option.unwrap(entry.title, ""),
              )
            }),
          ))
        }
        profile.Badges(_) -> {
          use badges <- promise.map(profile_api.badges(
            handle: handle,
            auth: token,
          ))
          Ok(profile.view(
            user,
            tab,
            [],
            [],
            list.map(page_or_empty(badges), fn(entry) {
              #(
                "/badge/" <> entry.id,
                option.unwrap(entry.image_url, ""),
                option.unwrap(entry.title, ""),
              )
            }),
          ))
        }
      }
  }
}

/// Editing is your own profile only, so it needs a session. Signed out, the
/// page would be a form that cannot save.
fn profile_edit_page(handle: String, req: Request) -> Promise(Response) {
  let ctx = ctx_of(req)
  case req.token {
    None ->
      promise.resolve(Redirect(
        "/signin?return=/profile/" <> handle <> "/edit",
        None,
      ))
    Some(_) -> {
      use result <- promise.await(profile_api.me(auth: req.token))
      case result {
        Ok(user) -> page(200, profile_edit.view(user, None), ctx)
        Error(err) -> {
          let #(status, message) = explain(err)
          page(status, error_page.view(status, message), ctx)
        }
      }
    }
  }
}

fn save_profile(handle: String, req: Request) -> Promise(Response) {
  let ctx = ctx_of(req)
  case req.token {
    None ->
      promise.resolve(Redirect(
        "/signin?return=/profile/" <> handle <> "/edit",
        None,
      ))
    Some(_) -> {
      use result <- promise.await(profile_api.update(
        nickname: option.unwrap(request.field(req, "nickname"), ""),
        bio: option.unwrap(request.field(req, "bio"), ""),
        auth: req.token,
      ))
      case result {
        // The handle can change with the nickname, so the saved record says
        // where to go rather than the URL this was posted to.
        Ok(saved) ->
          promise.resolve(Redirect(
            "/profile/" <> option.unwrap(saved.name, handle),
            None,
          ))
        Error(err) -> {
          use current <- promise.await(profile_api.me(auth: req.token))
          case current {
            Ok(user) ->
              page(200, profile_edit.view(user, Some(explain(err).1)), ctx)
            Error(_) -> {
              let #(status, message) = explain(err)
              page(status, error_page.view(status, message), ctx)
            }
          }
        }
      }
    }
  }
}

/// The four lists differ only by which filter the API is given.
fn event_filter(which: String) -> String {
  case which {
    "hosting" -> "owner_id"
    "co-hosting" -> "co_host_id"
    "starred" -> "starred_id"
    _ -> "attendee_id"
  }
}

/// A failed sub-list renders as empty rather than losing the whole profile:
/// the page is the person, not any one of their lists.
fn page_or_empty(result: Result(Page(a), ApiError)) -> List(a) {
  case result {
    Ok(page) -> page.data
    Error(_) -> []
  }
}

fn list_or_empty(result: Result(List(a), ApiError)) -> List(a) {
  case result {
    Ok(items) -> items
    Error(_) -> []
  }
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
  ctx: Ctx,
) -> Promise(Response) {
  use result <- promise.map(page)
  case result {
    Ok(body) -> Page(200, document(body, ctx))
    Error(err) -> {
      let #(status, message) = explain(err)
      Page(status, document(error_page.view(status, message), ctx))
    }
  }
}

fn page(status: Int, body: Element(msg), ctx: Ctx) -> Promise(Response) {
  promise.resolve(Page(status, document(body, ctx)))
}

/// Auth pages use the stripped header — showing Discover, search and a Sign In
/// button on the sign-in page itself would be odd, and upstream drops them.
fn auth_page(status: Int, body: Element(msg), ctx: Ctx) -> Promise(Response) {
  promise.resolve(Page(
    status,
    "<!doctype html>"
      <> element.to_string(layout.auth_document(
        body,
        layout.site_meta(),
        ctx.lang,
        ctx.path,
      )),
  ))
}

/// What the visitor is told, and under which status.
///
/// An upstream 404 stays a 404 and a refusal stays a refusal; anything else is
/// 502, because that failure is ours-to-them rather than theirs-to-the-visitor.
///
/// The wording is deliberately not about events. These messages started on the
/// event pages and now surface on group settings, profiles and every write
/// form, where "that event is not public" describes nothing that happened.
fn explain(err: ApiError) -> #(Int, String) {
  case err {
    HttpError(404, _) -> #(404, "Not found.")
    HttpError(401, _) | HttpError(403, _) -> #(
      403,
      "You do not have permission to do that.",
    )
    // A rejected write is the caller's to fix, not an outage. These were
    // being reported as 502s, which reads as "the site is broken" when the
    // actual answer — the API says so itself — is usually one bad field.
    HttpError(422, body) -> #(422, api_message(body))
    HttpError(400, body) -> #(400, api_message(body))
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

/// The API answers a rejected write with `{"error": "..."}`. That sentence is
/// the most useful thing anyone can be told, so it is shown rather than
/// paraphrased — pulled out by hand because it is one field and threading a
/// decoder through the error path would cost more than it explains.
pub fn api_message(body: String) -> String {
  case string.split_once(body, "\"error\":\"") {
    Ok(#(_, rest)) ->
      case string.split_once(rest, "\"") {
        Ok(#(message, _)) -> message
        Error(_) -> string.slice(body, 0, 200)
      }
    Error(_) -> string.slice(body, 0, 200)
  }
}

fn status_for(err: ApiError) -> Int {
  explain(err).0
}

/// A successful write does not render anything — it says where to go next.
fn to_destination(
  result: Result(a, ApiError),
  destination: String,
) -> Result(String, ApiError) {
  case result {
    Ok(_) -> Ok(destination)
    Error(err) -> Error(err)
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

fn document(body: Element(msg), ctx: Ctx) -> String {
  document_meta(body, ctx, layout.site_meta())
}

fn document_meta(body: Element(msg), ctx: Ctx, meta: layout.Meta) -> String {
  "<!doctype html>"
  <> element.to_string(layout.document_with(
    body,
    ctx.signed_in,
    meta,
    ctx.lang,
    ctx.path,
  ))
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

/// Sign-In with Ethereum. The signature is produced in the browser and posted
/// here rather than to the API directly, so the session cookie is set HttpOnly
/// by the same path as email sign-in instead of living in reachable script.
fn finish_wallet_signin(req: Request) -> Promise(Response) {
  let ctx = ctx_of(req)
  let back = option.unwrap(safe_return(request.field(req, "return")), "/")

  case request.field(req, "message"), request.field(req, "signature") {
    Some(message), Some(signature) -> {
      use result <- promise.await(auth.verify_wallet(message, signature))
      case result {
        Ok(session) -> promise.resolve(Redirect(back, Some(session.token)))
        // A 4xx here is a rejected signature or a domain the backend does not
        // allow, not an outage — say so on the sign-in page rather than
        // rendering a server error.
        Error(HttpError(status, _)) if status < 500 ->
          auth_page(
            200,
            signin.ask_email(
              Some("That wallet signature was not accepted."),
              safe_return(request.field(req, "return")),
              ctx.lang,
            ),
            ctx,
          )
        Error(err) ->
          auth_page(
            status_for(err),
            signin.ask_email(
              Some(explain(err).1),
              safe_return(request.field(req, "return")),
              ctx.lang,
            ),
            ctx,
          )
      }
    }
    _, _ -> promise.resolve(Redirect("/signin", None))
  }
}

/// Attending or leaving. Back to the event either way, where the panel now
/// reflects the change.
fn attend_event(id: String, req: Request) -> Promise(Response) {
  let back = "/event/detail/" <> id
  case req.token {
    None -> promise.resolve(Redirect("/signin?return=" <> back, None))
    Some(_) -> {
      let leaving = request.field(req, "action") == Some("leave")
      use _ <- promise.map(case leaving {
        True -> event.leave(id: id, auth: req.token)
        False -> event.attend(id: id, auth: req.token)
      })
      Redirect(back, None)
    }
  }
}

/// Leaving a comment. Back to the event either way — the page re-fetches the
/// list, so a successful comment is visible on arrival.
fn post_comment(id: String, req: Request) -> Promise(Response) {
  let ctx = ctx_of(req)
  let back = "/event/detail/" <> id
  case req.token, request.field(req, "content") {
    Some(token), Some(content) if content != "" -> {
      use _ <- promise.map(event.post_comment(
        id: id,
        content: content,
        auth: Some(token),
      ))
      Redirect(back, None)
    }
    // No session: the form is not shown to signed-out visitors, so this is
    // someone posting directly. Send them to sign in rather than failing.
    None, _ -> promise.resolve(Redirect("/signin?return=" <> back, None))
    _, _ -> promise.resolve(Redirect(back, None))
  }
}

/// The group's three write forms. All need a session and all resolve the
/// group first, so the shape is shared and only the fields differ.
fn group_form(
  handle: String,
  req: Request,
  which: String,
  problem: Option(String),
) -> Promise(Response) {
  let ctx = ctx_of(req)
  let back = "/event/" <> handle <> "/" <> form_path(which)
  case req.token {
    None -> promise.resolve(Redirect("/signin?return=" <> back, None))
    Some(_) -> {
      use found <- promise.await(group.detail(handle: handle, auth: req.token))
      case found {
        Error(err) -> {
          let #(status, message) = explain(err)
          page(status, error_page.view(status, message), ctx)
        }
        Ok(group) -> {
          let #(title, submit, fields) = case which {
            "venue" -> #(
              "Add a Venue",
              "Save",
              group_forms.venue_fields(),
            )
            "track" -> #(
              "Add a Program",
              "Save",
              group_forms.track_fields(),
            )
            _ -> #(
              "Group Settings",
              "Save",
              group_forms.settings_fields(group),
            )
          }
          page(
            200,
            group_forms.view(
              group,
              ctx.lang,
              title,
              back,
              submit,
              fields,
              problem,
            ),
            ctx,
          )
        }
      }
    }
  }
}

fn form_path(which: String) -> String {
  case which {
    "venue" -> "venues/create"
    "track" -> "tracks/create"
    _ -> "setting"
  }
}

/// Each save resolves the group, calls one endpoint, and either goes to the
/// page that now shows the result or comes back with what went wrong.
fn with_group(
  handle: String,
  req: Request,
  which: String,
  run: fn(GroupDetail) -> Promise(Result(String, ApiError)),
) -> Promise(Response) {
  let back = "/event/" <> handle <> "/" <> form_path(which)
  case req.token {
    None -> promise.resolve(Redirect("/signin?return=" <> back, None))
    Some(_) -> {
      use found <- promise.await(group.detail(handle: handle, auth: req.token))
      case found {
        Error(err) -> group_form(handle, req, which, Some(explain(err).1))
        Ok(group) -> {
          use result <- promise.await(run(group))
          case result {
            Ok(destination) -> promise.resolve(Redirect(destination, None))
            Error(err) -> group_form(handle, req, which, Some(explain(err).1))
          }
        }
      }
    }
  }
}

fn save_group_setting(handle: String, req: Request) -> Promise(Response) {
  use found <- with_group(handle, req, "setting")
  let field = fn(name) { option.unwrap(request.field(req, name), "") }
  use result <- promise.map(group.update(
    id: found.id,
    nickname: field("nickname"),
    bio: field("bio"),
    location: field("location"),
    auth: req.token,
  ))
  result |> to_destination("/event/" <> handle)
}

fn save_venue(handle: String, req: Request) -> Promise(Response) {
  use found <- with_group(handle, req, "venue")
  let field = fn(name) { option.unwrap(request.field(req, name), "") }
  use result <- promise.map(group.create_venue(
    group_id: found.id,
    name: field("name"),
    about: field("about"),
    capacity: group_forms.optional_int(field("capacity")),
    auth: req.token,
  ))
  result |> to_destination("/event/" <> handle <> "/venues")
}

fn save_track(handle: String, req: Request) -> Promise(Response) {
  use found <- with_group(handle, req, "track")
  let field = fn(name) { option.unwrap(request.field(req, name), "") }
  use result <- promise.map(group.create_track(
    group_id: found.id,
    title: field("title"),
    description: field("description"),
    auth: req.token,
  ))
  result |> to_destination("/event/" <> handle <> "/tracks")
}

/// Creating an event in a group. Needs a session; the API decides whether
/// this account may publish in that group.
fn event_create_page(
  handle: String,
  req: Request,
  problem: Option(String),
) -> Promise(Response) {
  let ctx = ctx_of(req)
  let back = "/event/" <> handle <> "/create"
  case req.token {
    None -> promise.resolve(Redirect("/signin?return=" <> back, None))
    Some(_) -> {
      use found <- promise.await(group.detail(handle: handle, auth: req.token))
      case found {
        Ok(group) ->
          page(200, event_create.view(group, ctx.lang, problem), ctx)
        Error(err) -> {
          let #(status, message) = explain(err)
          page(status, error_page.view(status, message), ctx)
        }
      }
    }
  }
}

fn create_event(handle: String, req: Request) -> Promise(Response) {
  let back = "/event/" <> handle <> "/create"
  case req.token {
    None -> promise.resolve(Redirect("/signin?return=" <> back, None))
    Some(_) -> {
      use found <- promise.await(group.detail(handle: handle, auth: req.token))
      case found {
        Error(err) -> event_create_page(handle, req, Some(explain(err).1))
        Ok(group) -> {
          let field = fn(name) { option.unwrap(request.field(req, name), "") }
          let zone = case field("timezone") {
            "" -> option.unwrap(group.timezone, "UTC")
            value -> value
          }
          use result <- promise.await(event.create(
            group_id: group.id,
            title: field("title"),
            content: field("content"),
            // `datetime-local` gives `2026-08-20T14:30`; the API wants a full
            // timestamp, and the seconds are the form's to supply, not the
            // reader's.
            start_time: field("start_time") <> ":00",
            end_time: field("end_time") <> ":00",
            timezone: zone,
            meeting_url: field("meeting_url"),
            auth: req.token,
          ))
          case result {
            Ok(created) ->
              promise.resolve(Redirect("/event/detail/" <> created.id, None))
            Error(err) ->
              event_create_page(handle, req, Some(explain(err).1))
          }
        }
      }
    }
  }
}

/// Choosing a username. Needs a session, since it names the account you are
/// already signed in to.
fn register_page(
  req: Request,
  taken: String,
  problem: Option(String),
) -> Promise(Response) {
  let ctx = ctx_of(req)
  case req.token {
    None -> promise.resolve(Redirect("/signin?return=/register", None))
    Some(_) -> page(200, register.view(ctx.lang, taken, problem), ctx)
  }
}

fn save_username(req: Request) -> Promise(Response) {
  let name = string.lowercase(option.unwrap(request.field(req, "name"), ""))

  case req.token, group.invalid_username(name) {
    None, _ -> promise.resolve(Redirect("/signin?return=/register", None))
    // The same rules as a group handle: it becomes the profile URL.
    _, Some(problem) -> register_page(req, name, Some(problem))
    Some(_), None -> {
      use result <- promise.await(profile_api.set_username(
        name: name,
        auth: req.token,
      ))
      case result {
        Ok(saved) ->
          promise.resolve(Redirect(
            "/profile/" <> option.unwrap(saved.name, name),
            None,
          ))
        Error(HttpError(status, _)) if status < 500 ->
          register_page(req, name, Some("That username is not available."))
        Error(err) -> register_page(req, name, Some(explain(err).1))
      }
    }
  }
}

/// Creating a group needs a session — the form would have nothing to post to.
fn group_create_page(
  req: Request,
  taken: String,
  problem: Option(String),
) -> Promise(Response) {
  let ctx = ctx_of(req)
  case req.token {
    None -> promise.resolve(Redirect("/signin?return=/group/create", None))
    Some(_) ->
      page(200, group_create.view(ctx.lang, taken, problem), ctx)
  }
}

fn create_group(req: Request) -> Promise(Response) {
  let name = string.lowercase(option.unwrap(request.field(req, "name"), ""))

  case req.token, group.invalid_name(name) {
    None, _ -> promise.resolve(Redirect("/signin?return=/group/create", None))
    // Checked here rather than left to the server: the name becomes the URL
    // and cannot be changed, so a rejection should arrive before the group
    // exists, not after.
    _, Some(problem) -> group_create_page(req, name, Some(problem))
    Some(_), None -> {
      use result <- promise.await(group.create(name: name, auth: req.token))
      case result {
        Ok(created) ->
          promise.resolve(Redirect(
            "/event/" <> option.unwrap(created.name, name),
            None,
          ))
        // A 4xx here is almost always the name being taken, which is a thing
        // to say on the form rather than an error page.
        Error(HttpError(status, _)) if status < 500 ->
          group_create_page(
            req,
            name,
            Some("That group name is not available."),
          )
        Error(err) -> group_create_page(req, name, Some(explain(err).1))
      }
    }
  }
}

fn my_events(req: Request) -> Promise(Response) {
  case req.token {
    None ->
      promise.resolve(Redirect("/signin?return=/my-events/attended", None))
    Some(_) -> {
      use result <- promise.map(profile_api.me(auth: req.token))
      case result {
        Ok(user) ->
          Redirect(
            "/profile/"
              <> option.unwrap(user.name, user.id)
              <> "?list=attending",
            None,
          )
        Error(_) -> Redirect("/signin?return=/my-events/attended", None)
      }
    }
  }
}

/// Only same-site paths are accepted as a post-sign-in destination.
///
/// `return` arrives in the URL, so anything absolute would let a link that
/// looks like our sign-in page hand the visitor to someone else's site once
/// they have signed in. A leading `//` is protocol-relative and is absolute
/// too, which is the case that a naive "starts with /" check lets through.
pub fn safe_return(value: Option(String)) -> Option(String) {
  case value {
    Some(path) ->
      case
        string.starts_with(path, "/") && !string.starts_with(path, "//")
      {
        True -> Some(path)
        False -> None
      }
    None -> None
  }
}
