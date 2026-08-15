//// Domain types mirroring the soon API (`https://api.sola.day/api/v1`).
////
//// Field names and nullability follow a real response captured from the live
//// API rather than the TypeScript declarations in `seastar-app`, because the
//// declarations there are hand-written and several fields typed non-optional
//// come back `null` in practice (`category`, `timezone`, `place`, `venue`,
//// `track`). When the two disagree, the wire wins.

import gleam/option.{type Option}

/// A person as embedded in `owner` / participant payloads.
pub type Profile {
  Profile(
    id: String,
    name: Option(String),
    nickname: Option(String),
    image_url: Option(String),
  )
}

/// A community. Embedded in an event as `group`.
pub type Group {
  Group(
    id: String,
    name: Option(String),
    nickname: Option(String),
    image_url: Option(String),
    logo_url: Option(String),
  )
}

/// A physical location attached to an event.
pub type Place {
  Place(
    id: String,
    title: Option(String),
    /// The API calls this `address`; `formatted_address` does not exist and
    /// silently decoded to None, so the address never rendered.
    address: Option(String),
    formatted_address: Option(String),
    location: Option(String),
  )
}

/// A named venue owned by a group.
pub type Venue {
  Venue(id: String, title: Option(String), location: Option(String))
}

/// A programme track used to group sessions within an event.
pub type Track {
  Track(id: String, title: Option(String), kind: Option(String))
}

/// An event. This is the shape returned by both `/events` (list) and
/// `/events/:id` (detail); the detail endpoint simply populates more of it.
pub type Event {
  Event(
    id: String,
    title: String,
    status: String,
    visibility: String,
    start_time: String,
    end_time: String,
    timezone: Option(String),
    cover: Option(String),
    notes: Option(String),
    /// The description. `notes` is a different, usually-empty field — the body
    /// people read lives here.
    content: Option(String),
    /// Hosts and co-hosts, as the API returns them.
    roles: List(EventRole),
    meeting_url: Option(String),
    external_url: Option(String),
    participant_count: Int,
    max_participant: Option(Int),
    require_approval: Bool,
    pinned: Bool,
    tags: List(String),
    owner: Option(Profile),
    group: Option(Group),
    place: Option(Place),
    venue: Option(Venue),
    track: Option(Track),
  )
}

/// A signed-in account. `name` is null until a username is chosen, which the
/// upstream app treats as "not finished signing up" rather than "signed in".
pub type User {
  User(id: String, email: Option(String), name: Option(String))
}

/// What `/auth/verify_code` hands back: the JWT plus enough of the user to
/// decide where to send them next.
pub type Session {
  Session(token: String, user: User)
}

/// A host or co-host on an event.
pub type EventRole {
  EventRole(
    display_name: Option(String),
    image_url: Option(String),
    role: Option(String),
  )
}

/// Pagination envelope. Every list endpoint wraps its rows in `data` and
/// reports `meta`.
pub type Page(a) {
  Page(data: List(a), meta: Meta)
}

pub type Meta {
  Meta(
    page: Int,
    limit: Int,
    total: Int,
    total_pages: Int,
    next_page: Option(Int),
    prev_page: Option(Int),
  )
}

/// Every failure the API layer can produce, kept separate from the transport
/// so callers can tell "the server said no" from "we could not read the reply".
pub type ApiError {
  /// Non-2xx. `body` is the raw payload; soon sends `{"error": "..."}`.
  HttpError(status: Int, body: String)
  /// 2xx whose body did not match the decoder — a schema drift signal.
  DecodeError(detail: String)
  /// The request never completed (DNS, TLS, timeout, offline).
  NetworkError(detail: String)
}

/// A popup city: a group with dates and a location, shown on the home page.
///
/// Only the fields the home page renders are modelled. The payload carries
/// ~30 keys; decoding all of them would be work in service of nothing, and
/// every one modelled is one more thing to keep in step with the API.
pub type PopupCity {
  PopupCity(
    id: String,
    name: Option(String),
    nickname: Option(String),
    image_url: Option(String),
    banner_image_url: Option(String),
    location: Option(String),
    start_date: Option(String),
    end_date: Option(String),
    group_tags: List(String),
  )
}

/// What `/discover` returns: the home page's whole payload in one request.
pub type Discover {
  Discover(
    popup_cities: List(PopupCity),
    groups: List(Group),
    communities: List(Group),
    events: List(Event),
  )
}

/// A group's full record, as returned by `/groups/:handle`.
pub type GroupDetail {
  GroupDetail(
    id: String,
    name: Option(String),
    nickname: Option(String),
    bio: Option(String),
    image_url: Option(String),
    logo_url: Option(String),
    banner_image_url: Option(String),
    location: Option(String),
    /// The group's own zone. The schedule's date window is computed in it —
    /// "today" in Bangkok is a different day from "today" in UTC for seven
    /// hours out of every twenty-four.
    timezone: Option(String),
    /// The tags this group's events can carry, in the order it defines them.
    /// The schedule's filter is built from this rather than from whatever
    /// happens to appear in the current week.
    event_tag_list: List(String),
    /// The group's venues arrive inside the group itself. There is no public
    /// `/venues?group_id=` — that endpoint is 401 for anonymous callers, and
    /// asking it turned this page into a 403 for everyone signed out.
    venues: List(VenueDetail),
    start_date: Option(String),
    end_date: Option(String),
    events_count: Int,
    memberships_count: Int,
  )
}

/// A badge class: the template a badge is minted from.
pub type BadgeClass {
  BadgeClass(
    id: String,
    title: Option(String),
    name: Option(String),
    content: Option(String),
    image_url: Option(String),
    badge_type: Option(String),
    counter: Int,
    creator: Option(Profile),
  )
}

/// A badge: one issued instance of a class, held by an owner.
pub type Badge {
  Badge(
    id: String,
    title: Option(String),
    content: Option(String),
    image_url: Option(String),
    status: Option(String),
    created_at: Option(String),
    owner: Option(Profile),
    creator: Option(Profile),
    badge_class: Option(BadgeClass),
  )
}

/// A public user profile.
pub type UserProfile {
  UserProfile(
    id: String,
    name: Option(String),
    nickname: Option(String),
    bio: Option(String),
    image_url: Option(String),
  )
}

/// A venue belonging to a group.
pub type VenueDetail {
  VenueDetail(
    id: String,
    name: Option(String),
    about: Option(String),
    capacity: Option(Int),
    featured_image_url: Option(String),
    tags: List(String),
  )
}

/// What `/search` returns: four independent result sets for one keyword.
pub type SearchResults {
  SearchResults(
    events: List(Event),
    groups: List(Group),
    users: List(UserProfile),
    badge_classes: List(BadgeClass),
  )
}

/// Someone's membership of a group, with the role that governs what they may
/// do there.
pub type Membership {
  Membership(id: String, role: Option(String), user: Option(Profile))
}

/// A programme track, with the dates it runs.
pub type TrackDetail {
  TrackDetail(
    id: String,
    title: Option(String),
    description: Option(String),
    start_date: Option(String),
    end_date: Option(String),
  )
}
