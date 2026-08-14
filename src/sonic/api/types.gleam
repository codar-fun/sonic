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
