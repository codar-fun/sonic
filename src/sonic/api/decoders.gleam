//// Decoders for the soon API payloads.
////
//// Nullable-vs-absent: the API sends explicit `null` for empty scalars, but a
//// few fields are omitted entirely on the list endpoint. `optional_field` with
//// a `None` default covers both, so a missing key is not a decode failure —
//// only a *wrongly typed* one is. That keeps schema drift loud (a String where
//// an Int belongs fails) without making the client brittle to added/removed
//// optional keys.

import gleam/dynamic/decode.{type Decoder}
import gleam/option.{type Option, None}
import sonic/api/types.{
  type Badge, type BadgeClass, type Discover, type Event, type EventRole,
  type Group, type GroupDetail, type Membership, type Meta, type Page,
  type Place, type PopupCity, type Profile, type SearchResults, type Track,
  type TrackDetail, type UserProfile, type Venue, type VenueDetail, Badge,
  BadgeClass, Discover, Event, EventRole, Group, GroupDetail, Membership, Meta,
  Page, Place, PopupCity, Profile, SearchResults, Track, TrackDetail,
  UserProfile, Venue, VenueDetail,
}

/// `optional_field` with a `None` default: tolerates both `null` and absent.
fn opt(name: String, inner: Decoder(a), next: fn(Option(a)) -> Decoder(b)) {
  decode.optional_field(name, None, decode.optional(inner), next)
}

/// Like `opt` but for non-optional fields with a sensible default.
///
/// `decode.optional_field` alone only covers an *absent* key — an explicit
/// `null` still runs the inner decoder and fails. The API sends both: one event
/// in twenty carries `"require_approval": null`, which 502'd the whole page
/// until this existed. Absent and null must mean the same thing here.
fn opt_or(
  name: String,
  default: a,
  inner: Decoder(a),
  next: fn(a) -> Decoder(b),
) {
  decode.optional_field(
    name,
    default,
    decode.optional(inner)
      |> decode.map(fn(value) { option.unwrap(value, default) }),
    next,
  )
}

pub fn profile() -> Decoder(Profile) {
  use id <- decode.field("id", decode.string)
  use name <- opt("name", decode.string)
  use nickname <- opt("nickname", decode.string)
  use image_url <- opt("image_url", decode.string)
  decode.success(Profile(id:, name:, nickname:, image_url:))
}

pub fn group() -> Decoder(Group) {
  use id <- decode.field("id", decode.string)
  use name <- opt("name", decode.string)
  use nickname <- opt("nickname", decode.string)
  use image_url <- opt("image_url", decode.string)
  use logo_url <- opt("logo_url", decode.string)
  decode.success(Group(id:, name:, nickname:, image_url:, logo_url:))
}

pub fn place() -> Decoder(Place) {
  use id <- decode.field("id", decode.string)
  use title <- opt("title", decode.string)
  use address <- opt("address", decode.string)
  use formatted_address <- opt("formatted_address", decode.string)
  use location <- opt("location", decode.string)
  decode.success(Place(id:, title:, address:, formatted_address:, location:))
}

pub fn venue() -> Decoder(Venue) {
  use id <- decode.field("id", decode.string)
  use title <- opt("title", decode.string)
  use location <- opt("location", decode.string)
  decode.success(Venue(id:, title:, location:))
}

pub fn track() -> Decoder(Track) {
  use id <- decode.field("id", decode.string)
  use title <- opt("title", decode.string)
  use kind <- opt("kind", decode.string)
  decode.success(Track(id:, title:, kind:))
}

pub fn event() -> Decoder(Event) {
  use id <- decode.field("id", decode.string)
  use title <- decode.field("title", decode.string)
  use status <- decode.field("status", decode.string)
  use visibility <- decode.field("visibility", decode.string)
  use start_time <- decode.field("start_time", decode.string)
  use end_time <- decode.field("end_time", decode.string)
  use timezone <- opt("timezone", decode.string)
  // The API calls this `image_url`; we call it `cover` internally because
  // `image_url` also exists on group/owner and reads ambiguously in views.
  use cover <- opt("image_url", decode.string)
  use notes <- opt("notes", decode.string)
  use content <- opt("content", decode.string)
  use roles <- opt_or("event_roles", [], decode.list(event_role()))
  use meeting_url <- opt("meeting_url", decode.string)
  use external_url <- opt("external_url", decode.string)
  use participant_count <- opt_or("participant_count", 0, decode.int)
  use max_participant <- opt("max_participant", decode.int)
  use require_approval <- opt_or("require_approval", False, decode.bool)
  use pinned <- opt_or("pinned", False, decode.bool)
  use tags <- opt_or("tags", [], decode.list(decode.string))
  use owner <- opt("owner", profile())
  use group <- opt("group", group())
  use place <- opt("place", place())
  use venue <- opt("venue", venue())
  use track <- opt("track", track())
  decode.success(Event(
    id:,
    title:,
    status:,
    visibility:,
    start_time:,
    end_time:,
    timezone:,
    cover:,
    notes:,
    content:,
    roles:,
    meeting_url:,
    external_url:,
    participant_count:,
    max_participant:,
    require_approval:,
    pinned:,
    tags:,
    owner:,
    group:,
    place:,
    venue:,
    track:,
  ))
}

pub fn event_role() -> Decoder(EventRole) {
  use display_name <- opt("display_name", decode.string)
  use image_url <- opt("image_url", decode.string)
  use role <- opt("role", decode.string)
  decode.success(EventRole(display_name:, image_url:, role:))
}

pub fn meta() -> Decoder(Meta) {
  use page <- opt_or("page", 1, decode.int)
  use limit <- opt_or("limit", 0, decode.int)
  use total <- opt_or("total", 0, decode.int)
  use total_pages <- opt_or("total_pages", 0, decode.int)
  use next_page <- opt("next_page", decode.int)
  use prev_page <- opt("prev_page", decode.int)
  decode.success(Meta(
    page:,
    limit:,
    total:,
    total_pages:,
    next_page:,
    prev_page:,
  ))
}

/// `{"data": [...], "meta": {...}}` as returned by every list endpoint.
pub fn page(of inner: Decoder(a)) -> Decoder(Page(a)) {
  use data <- decode.field("data", decode.list(inner))
  use meta <- decode.field("meta", meta())
  decode.success(Page(data:, meta:))
}

pub fn popup_city() -> Decoder(PopupCity) {
  use id <- decode.field("id", decode.string)
  use name <- opt("name", decode.string)
  use nickname <- opt("nickname", decode.string)
  use image_url <- opt("image_url", decode.string)
  use banner_image_url <- opt("banner_image_url", decode.string)
  use location <- opt("location", decode.string)
  use start_date <- opt("start_date", decode.string)
  use end_date <- opt("end_date", decode.string)
  use group_tags <- opt_or("group_tags", [], decode.list(decode.string))
  decode.success(PopupCity(
    id:,
    name:,
    nickname:,
    image_url:,
    banner_image_url:,
    location:,
    start_date:,
    end_date:,
    group_tags:,
  ))
}

/// `/discover` — the home page's entire payload. Every list defaults to empty
/// rather than failing: the endpoint genuinely returns `communities: []`, and a
/// home page that 502s because one section is empty would be worse than one
/// that renders the sections it has.
pub fn discover() -> Decoder(Discover) {
  use popup_cities <- decode.optional_field(
    "popup_cities",
    [],
    decode.list(popup_city()),
  )
  use groups <- decode.optional_field("groups", [], decode.list(group()))
  use communities <- decode.optional_field(
    "communities",
    [],
    decode.list(group()),
  )
  use events <- decode.optional_field("events", [], decode.list(event()))
  decode.success(Discover(popup_cities:, groups:, communities:, events:))
}

pub fn group_detail() -> Decoder(GroupDetail) {
  use id <- decode.field("id", decode.string)
  use name <- opt("name", decode.string)
  use nickname <- opt("nickname", decode.string)
  use bio <- opt("bio", decode.string)
  use image_url <- opt("image_url", decode.string)
  use logo_url <- opt("logo_url", decode.string)
  use banner_image_url <- opt("banner_image_url", decode.string)
  use location <- opt("location", decode.string)
  use start_date <- opt("start_date", decode.string)
  use end_date <- opt("end_date", decode.string)
  use events_count <- opt_or("events_count", 0, decode.int)
  use memberships_count <- opt_or("memberships_count", 0, decode.int)
  decode.success(GroupDetail(
    id:,
    name:,
    nickname:,
    bio:,
    image_url:,
    logo_url:,
    banner_image_url:,
    location:,
    start_date:,
    end_date:,
    events_count:,
    memberships_count:,
  ))
}

pub fn badge_class() -> Decoder(BadgeClass) {
  use id <- decode.field("id", decode.string)
  use title <- opt("title", decode.string)
  use name <- opt("name", decode.string)
  use content <- opt("content", decode.string)
  use image_url <- opt("image_url", decode.string)
  use badge_type <- opt("badge_type", decode.string)
  use counter <- opt_or("counter", 0, decode.int)
  use creator <- opt("creator", profile())
  decode.success(BadgeClass(
    id:,
    title:,
    name:,
    content:,
    image_url:,
    badge_type:,
    counter:,
    creator:,
  ))
}

pub fn badge() -> Decoder(Badge) {
  use id <- decode.field("id", decode.string)
  use title <- opt("title", decode.string)
  use content <- opt("content", decode.string)
  use image_url <- opt("image_url", decode.string)
  use status <- opt("status", decode.string)
  use created_at <- opt("created_at", decode.string)
  use owner <- opt("owner", profile())
  use creator <- opt("creator", profile())
  use badge_class <- opt("badge_class", badge_class())
  decode.success(Badge(
    id:,
    title:,
    content:,
    image_url:,
    status:,
    created_at:,
    owner:,
    creator:,
    badge_class:,
  ))
}

pub fn user_profile() -> Decoder(UserProfile) {
  use id <- decode.field("id", decode.string)
  use name <- opt("name", decode.string)
  use nickname <- opt("nickname", decode.string)
  use bio <- opt("bio", decode.string)
  use image_url <- opt("image_url", decode.string)
  decode.success(UserProfile(id:, name:, nickname:, bio:, image_url:))
}

pub fn venue_detail() -> Decoder(VenueDetail) {
  use id <- decode.field("id", decode.string)
  use name <- opt("name", decode.string)
  use about <- opt("about", decode.string)
  use capacity <- opt("capacity", decode.int)
  use featured_image_url <- opt("featured_image_url", decode.string)
  use tags <- opt_or("tags", [], decode.list(decode.string))
  decode.success(VenueDetail(
    id:,
    name:,
    about:,
    capacity:,
    featured_image_url:,
    tags:,
  ))
}

/// Every list defaults to empty: a keyword matching only events must still
/// render, rather than failing because `badge_classes` was omitted.
pub fn search_results() -> Decoder(SearchResults) {
  use events <- opt_or("events", [], decode.list(event()))
  use groups <- opt_or("groups", [], decode.list(group()))
  use users <- opt_or("users", [], decode.list(user_profile()))
  use badge_classes <- opt_or("badge_classes", [], decode.list(badge_class()))
  decode.success(SearchResults(events:, groups:, users:, badge_classes:))
}

pub fn membership() -> Decoder(Membership) {
  use id <- decode.field("id", decode.string)
  use role <- opt("role", decode.string)
  use user <- opt("user", profile())
  decode.success(Membership(id:, role:, user:))
}

pub fn track_detail() -> Decoder(TrackDetail) {
  use id <- decode.field("id", decode.string)
  use title <- opt("title", decode.string)
  use description <- opt("description", decode.string)
  use start_date <- opt("start_date", decode.string)
  use end_date <- opt("end_date", decode.string)
  decode.success(TrackDetail(id:, title:, description:, start_date:, end_date:))
}
