//// Group endpoints.
////
//// Groups are addressed by handle in URLs and by id in most payloads; the
//// handle is the `name` field. These take the handle, matching what the router
//// hands over.

import gleam/int
import gleam/json
import gleam/list
import gleam/javascript/promise.{type Promise}
import gleam/option.{type Option, None, Some}
import gleam/string
import sonic/api/client.{type ApiResult, type Auth}
import sonic/api/decoders
import sonic/api/types.{
  type Event, type GroupDetail, type Membership, type Page, type TrackDetail,
  type VenueDetail, Page,
}

/// `GET /groups/:handle` — one group's full record.
pub fn detail(
  handle handle: String,
  auth auth: Auth,
) -> Promise(ApiResult(GroupDetail)) {
  client.get(
    path: "/groups/" <> handle,
    query: [],
    auth: auth,
    expect: decoders.group_detail(),
  )
}

/// `GET /events?group_id=…` — that group's events.
///
/// The parameter is `group_id`, and it accepts a handle as well as a TSID.
/// `group_handle` is *not* a filter the API knows: it is accepted, ignored,
/// and answered with every event on the platform — which renders as a
/// plausible-looking page belonging to the wrong group.
pub fn events(
  handle handle: String,
  page page: Int,
  limit limit: Int,
  collection collection: String,
  auth auth: Auth,
) -> Promise(ApiResult(Page(Event))) {
  client.get(
    path: "/events",
    query: [
      #("group_id", Some(handle)),
      // The SDK calls this `collection`; upcoming/past is a server-side split,
      // not something to filter client-side against a clock we do not have.
      #("collection", Some(collection)),
      #("page", Some(int.to_string(page))),
      #("limit", Some(int.to_string(limit))),
    ],
    auth: auth,
    expect: decoders.page(of: decoders.event()),
  )
}

/// `GET /events?group_id=…&start_date=…&end_date=…` — a group's events inside
/// a date window.
///
/// The schedule asks for a window rather than a page: upstream loads one week
/// for the list and week views and one day for compact and venue, then groups
/// what comes back. Paging by count instead returned the group's entire
/// history, which is why the schedule was showing hundreds of past events
/// under a heading that says this week.
///
/// The limit matches upstream's 400 — the window bounds the result, and a
/// smaller page would silently cut a busy week short.
pub fn schedule_events(
  handle handle: String,
  from from: String,
  to to: String,
  timezone timezone: Option(String),
  tags tags: List(String),
  auth auth: Auth,
) -> Promise(ApiResult(Page(Event))) {
  client.get(
    path: "/events",
    query: [
      #("group_id", Some(handle)),
      #("start_date", Some(from)),
      #("end_date", Some(to)),
      #("timezone", timezone),
      // Comma-joined, as upstream sends it. Empty means no tag filter at all,
      // which is different from "match nothing".
      #("tags", case tags {
        [] -> None
        values -> Some(string.join(values, ","))
      }),
      #("limit", Some("400")),
    ],
    auth: auth,
    expect: decoders.page(of: decoders.event()),
  )
}

/// `POST /groups` — create a group with this handle.
pub fn create(
  name name: String,
  auth auth: Auth,
) -> Promise(ApiResult(GroupDetail)) {
  client.post(
    path: "/groups",
    query: [],
    auth: auth,
    body: json.object([#("group", json.object([#("name", json.string(name))]))]),
    expect: decoders.group_detail(),
  )
}

/// `PATCH /groups/:id` — group settings.
///
/// Only the fields the settings form owns. The full record carries tags,
/// banner, permissions and timezone, each with its own page upstream, and a
/// PATCH that sent them all would write over whatever this form did not ask.
pub fn update(
  id id: String,
  nickname nickname: String,
  bio bio: String,
  location location: String,
  auth auth: Auth,
) -> Promise(ApiResult(GroupDetail)) {
  client.patch(
    path: "/groups/" <> id,
    query: [],
    auth: auth,
    body: json.object([
      #(
        "group",
        json.object([
          #("nickname", json.string(nickname)),
          #("bio", json.string(bio)),
          #("location", json.string(location)),
        ]),
      ),
    ]),
    expect: decoders.group_detail(),
  )
}

/// `POST /venues` — add a venue to a group.
pub fn create_venue(
  group_id group_id: String,
  name name: String,
  about about: String,
  capacity capacity: Option(Int),
  auth auth: Auth,
) -> Promise(ApiResult(VenueDetail)) {
  client.post(
    path: "/venues",
    query: [],
    auth: auth,
    body: json.object([
      #(
        "venue",
        json.object([
          #("group_id", json.string(group_id)),
          #("name", json.string(name)),
          #("about", json.string(about)),
          #("capacity", case capacity {
            Some(n) -> json.int(n)
            None -> json.null()
          }),
        ]),
      ),
    ]),
    expect: decoders.venue_detail(),
  )
}

/// `POST /tracks` — add a programme to a group.
pub fn create_track(
  group_id group_id: String,
  title title: String,
  description description: String,
  auth auth: Auth,
) -> Promise(ApiResult(TrackDetail)) {
  client.post(
    path: "/tracks",
    query: [],
    auth: auth,
    body: json.object([
      #(
        "track",
        json.object([
          #("group_id", json.string(group_id)),
          #("title", json.string(title)),
          #("description", json.string(description)),
        ]),
      ),
    ]),
    expect: decoders.track_detail(),
  )
}

/// The group handle rules, checked before the request rather than after.
///
/// Taken from soon's own model — `/\A[a-z0-9_-]{3,30}\z/` — not from
/// upstream's client-side `verifyUsername`, which allows hyphens where the
/// API wants underscores and caps at 20 where the API allows 30. Copying the
/// client meant rejecting names the server accepts and accepting names it
/// rejects, which surfaced as "that name is not available" for a perfectly
/// good one.
///
/// The 6-character minimum and the no-edge-hyphen rules are upstream's own,
/// stricter than the API on purpose; the name becomes the URL and cannot be
/// changed, so the stricter reading is the kind one.
pub fn invalid_name(name: String) -> Option(String) {
  check(name, "group name", "abcdefghijklmnopqrstuvwxyz0123456789_-")
}

/// Usernames are *not* the same: soon's user model is `[a-z0-9_]`, with no
/// hyphen. One shared validator would have to be wrong for one of them.
pub fn invalid_username(name: String) -> Option(String) {
  check(name, "username", "abcdefghijklmnopqrstuvwxyz0123456789_")
}

fn check(name: String, what: String, alphabet: String) -> Option(String) {
  let length = string.length(name)
  case name {
    "" -> Some("Please input a " <> what)
    _ ->
      case
        string.starts_with(name, "-"),
        string.ends_with(name, "-"),
        length < 6,
        length > 30,
        list.all(string.to_graphemes(name), fn(c) {
          string.contains(alphabet, c)
        })
        && !string.contains(name, "--")
      {
        True, _, _, _, _ -> Some("A " <> what <> " cannot start with \"-\"")
        _, True, _, _, _ -> Some("A " <> what <> " cannot end with \"-\"")
        _, _, True, _, _ ->
          Some("The minimum length of a " <> what <> " is 6")
        _, _, _, True, _ ->
          Some("The maximum length of a " <> what <> " is 30")
        _, _, _, _, False ->
          Some("A " <> what <> " may only contain " <> describe(alphabet))
        _, _, _, _, True -> None
      }
  }
}

fn describe(alphabet: String) -> String {
  case string.contains(alphabet, "-") {
    True -> "lowercase letters, digits, underscores or hyphens"
    False -> "lowercase letters, digits or underscores"
  }
}

/// `GET /groups/directory` — every active group, for `/communities`.
///
/// A different question from `/discover`'s curated slice: this is the full
/// list, which is why an untagged group appears here and nowhere else.
pub fn directory(
  page page: Int,
  limit limit: Int,
  auth auth: Auth,
) -> Promise(ApiResult(Page(GroupDetail))) {
  client.get(
    path: "/groups/directory",
    query: [
      #("page", Some(int.to_string(page))),
      #("limit", Some(int.to_string(limit))),
    ],
    auth: auth,
    expect: decoders.page(of: decoders.group_detail()),
  )
}

/// Every group in the directory, following the pagination to the end.
///
/// The endpoint caps a page at 100 and there are over four hundred groups, so
/// asking for one page showed a quarter of the directory with nothing to say
/// so. Upstream walks the pages too (`requestAllPages`).
///
/// Bounded at ten pages: a thousand groups is far past anything this page can
/// usefully render, and an unbounded loop against a paginated endpoint is one
/// bad `total_pages` away from never returning.
pub fn all_directory(auth auth: Auth) -> Promise(ApiResult(Page(GroupDetail))) {
  collect_directory(1, [], auth)
}

fn collect_directory(
  page_number: Int,
  seen: List(GroupDetail),
  auth: Auth,
) -> Promise(ApiResult(Page(GroupDetail))) {
  use result <- promise.await(directory(
    page: page_number,
    limit: 100,
    auth: auth,
  ))
  case result {
    Error(err) -> promise.resolve(Error(err))
    Ok(page) -> {
      let gathered = list.append(seen, page.data)
      case page.meta.next_page, page_number >= 10 {
        Some(next), False -> collect_directory(next, gathered, auth)
        _, _ -> promise.resolve(Ok(Page(data: gathered, meta: page.meta)))
      }
    }
  }
}

/// `GET /groups/:id/memberships` — who belongs, and in what role.
///
/// Keyed by id rather than handle, unlike the other group calls.
pub fn memberships(
  group_id group_id: String,
  auth auth: Auth,
) -> Promise(ApiResult(Page(Membership))) {
  client.get(
    path: "/groups/" <> group_id <> "/memberships",
    query: [#("limit", Some(int.to_string(200)))],
    auth: auth,
    expect: decoders.page(of: decoders.membership()),
  )
}

/// `GET /tracks?group_id=…`
pub fn tracks(
  group_id group_id: String,
  auth auth: Auth,
) -> Promise(ApiResult(Page(TrackDetail))) {
  client.get(
    path: "/tracks",
    query: [#("group_id", Some(group_id)), #("limit", Some(int.to_string(100)))],
    auth: auth,
    expect: decoders.page(of: decoders.track_detail()),
  )
}
