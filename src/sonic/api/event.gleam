//// Event endpoints.
////
//// Each function is one call site: a path, its parameters, and the decoder for
//// what comes back. No logic lives here — sorting, grouping and formatting are
//// the view layer's job, so these stay trivially readable against the API.

import gleam/int
import gleam/javascript/promise.{type Promise}
import gleam/option.{type Option, None, Some}
import sonic/api/client.{type ApiResult, type Auth}
import sonic/api/decoders
import gleam/dynamic/decode
import gleam/json
import gleam/list
import sonic/api/types.{
  type Comment, type Discover, type Event, type Page, type Participant,
}

/// `GET /events` — a page of public events, newest page first.
pub fn list(
  page page: Int,
  limit limit: Int,
  auth auth: Auth,
) -> Promise(ApiResult(Page(Event))) {
  client.get(
    path: "/events",
    query: [
      #("page", Some(int.to_string(page))),
      #("limit", Some(int.to_string(limit))),
    ],
    auth: auth,
    expect: decoders.page(of: decoders.event()),
  )
}

/// `GET /events/:id` — one event, with the detail fields populated.
pub fn detail(id id: String, auth auth: Auth) -> Promise(ApiResult(Event)) {
  client.get(
    path: "/events/" <> id,
    query: [],
    auth: auth,
    expect: decoders.event(),
  )
}

/// `GET /events` scoped to a group handle, used by the group landing page.
pub fn list_for_group(
  handle handle: String,
  page page: Int,
  limit limit: Int,
  auth auth: Auth,
) -> Promise(ApiResult(Page(Event))) {
  client.get(
    path: "/events",
    query: [
      #("group_handle", Some(handle)),
      #("page", Some(int.to_string(page))),
      #("limit", Some(int.to_string(limit))),
    ],
    auth: auth,
    expect: decoders.page(of: decoders.event()),
  )
}

/// Events the signed-in user is attending. Requires a token; without one the
/// API answers 401 and the caller gets `HttpError(401, _)` rather than an
/// empty list, so "not signed in" never masquerades as "nothing to show".
pub fn mine(auth auth: Auth) -> Promise(ApiResult(Page(Event))) {
  client.get(
    path: "/events/my_events",
    query: [#("page", Some("1")), #("limit", Some("20"))],
    auth: auth,
    expect: decoders.page(of: decoders.event()),
  )
}

/// The upstream app links out to an `.ics` file rather than building one, so
/// this returns the URL instead of fetching it.
/// `GET /events/:id/participants` — who is attending.
///
/// Public: the detail page's Participants tab shows this to anyone, signed in
/// or not, exactly as upstream does.
pub fn participants(id id: String) -> Promise(ApiResult(Page(Participant))) {
  client.get(
    path: "/events/" <> id <> "/participants",
    query: [],
    auth: None,
    expect: decoders.page(of: decoders.participant()),
  )
}

/// `POST /events/:id/participants` — attend an event.
pub fn attend(id id: String, auth auth: Auth) -> Promise(ApiResult(Nil)) {
  client.post(
    path: "/events/" <> id <> "/participants",
    query: [],
    auth: auth,
    body: json.object([
      #("participant", json.object([#("status", json.string("attending"))])),
    ]),
    expect: decode.success(Nil),
  )
}

/// Leave an event.
///
/// There is no "delete my attendance" endpoint: the participant record has to
/// be found first, and it is found by matching the caller's own id against the
/// attendee list. Upstream walks every page for it; this asks for the caller
/// once and then pages, stopping at the match.
pub fn leave(id id: String, auth auth: Auth) -> Promise(ApiResult(Nil)) {
  use me <- promise.await(current_user_id(auth))
  case me {
    Error(err) -> promise.resolve(Error(err))
    Ok(user_id) -> {
      use found <- promise.await(participants(id: id))
      case found {
        Error(err) -> promise.resolve(Error(err))
        Ok(page) ->
          case
            list.find(page.data, fn(entry) {
              case entry.user {
                Some(user) -> user.id == user_id
                None -> False
              }
            })
          {
            Ok(mine) ->
              client.delete(
                path: "/events/" <> id <> "/participants/" <> mine.id,
                query: [],
                auth: auth,
              )
            // Not attending is not a failure: the desired state already holds.
            Error(_) -> promise.resolve(Ok(Nil))
          }
      }
    }
  }
}

/// Is the caller on this event's attendee list?
///
/// The attendee list is public, so this is one request rather than a
/// participant lookup per visitor.
pub fn is_attending(id id: String, auth auth: Auth) -> Promise(Bool) {
  use me <- promise.await(current_user_id(auth))
  case me {
    Error(_) -> promise.resolve(False)
    Ok(user_id) -> {
      use found <- promise.map(participants(id: id))
      case found {
        Error(_) -> False
        Ok(page) ->
          list.any(page.data, fn(entry) {
            case entry.user {
              Some(user) -> user.id == user_id
              None -> False
            }
          })
      }
    }
  }
}

fn current_user_id(auth: Auth) -> Promise(ApiResult(String)) {
  client.get(path: "/users/me", query: [], auth: auth, expect: {
    use id <- decode.field("id", decode.string)
    decode.success(id)
  })
}

/// `POST /events/:id/participants/check_in` — mark someone as arrived.
pub fn check_in(
  id id: String,
  user_id user_id: String,
  auth auth: Auth,
) -> Promise(ApiResult(Nil)) {
  client.post(
    path: "/events/" <> id <> "/participants/check_in",
    query: [],
    auth: auth,
    body: json.object([#("user_id", json.string(user_id))]),
    expect: decode.success(Nil),
  )
}

/// `POST /events` — create an event in a group.
///
/// The full draft upstream sends carries roles, tickets, recurrence and a
/// resolved place id. This sends the fields the form collects and leaves the
/// rest to the API's defaults: a partial event that is correct beats a full
/// one built from guesses about fields the form never asked for.
pub fn create(
  group_id group_id: String,
  title title: String,
  content content: String,
  start_time start_time: String,
  end_time end_time: String,
  timezone timezone: String,
  meeting_url meeting_url: String,
  auth auth: Auth,
) -> Promise(ApiResult(Event)) {
  client.post(
    path: "/events",
    query: [],
    auth: auth,
    body: json.object([
      #(
        "event",
        json.object([
          #("group_id", json.string(group_id)),
          #("title", json.string(title)),
          #("content", json.string(content)),
          #("start_time", json.string(start_time)),
          #("end_time", json.string(end_time)),
          #("timezone", json.string(timezone)),
          #("meeting_url", json.string(meeting_url)),
          #("status", json.string("published")),
          #("visibility", json.string("public")),
        ]),
      ),
    ]),
    expect: decoders.event(),
  )
}

/// `GET /comments?comment_type=comment&item_type=Event&item_id=…`
///
/// `comment_type` is not optional even though it looks it: soon's index
/// filters on it unconditionally, so omitting it matches `comment_type IS
/// NULL` and returns an empty list for every event — which reads exactly like
/// "no comments yet".
pub fn comments(id id: String) -> Promise(ApiResult(Page(Comment))) {
  client.get(
    path: "/comments",
    query: [
      #("comment_type", Some("comment")),
      #("item_type", Some("Event")),
      #("item_id", Some(id)),
    ],
    auth: None,
    expect: decoders.page(of: decoders.comment()),
  )
}

/// `POST /comments` — leave a comment on an event.
pub fn post_comment(
  id id: String,
  content content: String,
  auth auth: Auth,
) -> Promise(ApiResult(Comment)) {
  client.post(
    path: "/comments",
    query: [],
    auth: auth,
    body: json.object([
      #(
        "comment",
        json.object([
          #("comment_type", json.string("comment")),
          #("item_type", json.string("Event")),
          #("item_id", json.string(id)),
          #("content", json.string(content)),
          #("content_type", json.string("text")),
        ]),
      ),
    ]),
    expect: decoders.comment(),
  )
}

/// `GET /recurring/:id` — the series an event belongs to.
///
/// Only the interval is decoded. The payload also carries every instance,
/// which the detail page does not show and which grows without bound on a
/// weekly series that has been running for a year.
pub fn recurring_interval(id id: String) -> Promise(ApiResult(String)) {
  client.get(
    path: "/recurring/" <> id,
    query: [],
    auth: None,
    expect: decoders.recurring_interval(),
  )
}

pub fn calendar_url(id: String) -> String {
  client.base_url <> "/api/v1/events/" <> id <> "/calendar.ics"
}

/// Convenience for pages that only need the first page of results.
pub fn first_page(
  limit limit: Int,
  auth auth: Auth,
) -> Promise(ApiResult(Page(Event))) {
  list(page: 1, limit: limit, auth: auth)
}

/// Unwrap an optional token from a request context.
pub fn token(value: Option(String)) -> Auth {
  case value {
    Some("") -> None
    other -> other
  }
}

/// `GET /discover` — the home page's whole payload in one request.
///
/// Lives here rather than in its own module because it is one call; if the
/// home page grows more sources this moves to `sonic/api/discover`.
pub fn discover() -> Promise(ApiResult(Discover)) {
  client.get(
    path: "/discover",
    query: [],
    auth: None,
    expect: decoders.discover(),
  )
}
