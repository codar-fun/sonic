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
  type Event, type Group, type Meta, type Page, type Place, type Profile,
  type Track, type Venue, Event, Group, Meta, Page, Place, Profile, Track, Venue,
}

/// `optional_field` with a `None` default: tolerates both `null` and absent.
fn opt(name: String, inner: Decoder(a), next: fn(Option(a)) -> Decoder(b)) {
  decode.optional_field(name, None, decode.optional(inner), next)
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
  use formatted_address <- opt("formatted_address", decode.string)
  use location <- opt("location", decode.string)
  decode.success(Place(id:, title:, formatted_address:, location:))
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
  use meeting_url <- opt("meeting_url", decode.string)
  use external_url <- opt("external_url", decode.string)
  use participant_count <- decode.optional_field(
    "participant_count",
    0,
    decode.int,
  )
  use max_participant <- opt("max_participant", decode.int)
  use require_approval <- decode.optional_field(
    "require_approval",
    False,
    decode.bool,
  )
  use pinned <- decode.optional_field("pinned", False, decode.bool)
  use tags <- decode.optional_field("tags", [], decode.list(decode.string))
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

pub fn meta() -> Decoder(Meta) {
  use page <- decode.optional_field("page", 1, decode.int)
  use limit <- decode.optional_field("limit", 0, decode.int)
  use total <- decode.optional_field("total", 0, decode.int)
  use total_pages <- decode.optional_field("total_pages", 0, decode.int)
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
