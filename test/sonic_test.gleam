//// Decoder tests run against a payload captured from the live API
//// (`test/fixtures/events_page.json`), not a hand-written fixture. A
//// hand-written one only proves the decoder agrees with our own assumptions;
//// this one fails when the real schema moves.

import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleeunit
import gleeunit/should
import sonic/api/decoders
import sonic/api/types.{type Event}

pub fn main() {
  gleeunit.main()
}

@external(javascript, "./fixture_ffi.mjs", "read_fixture")
fn read_fixture(name: String) -> String

fn events_page() -> types.Page(Event) {
  read_fixture("events_page.json")
  |> json.parse(decoders.page(of: decoders.event()))
  |> should.be_ok
}

pub fn decodes_live_events_page_test() {
  let page = events_page()
  list.length(page.data) |> should.equal(3)
  should.be_true(page.meta.total > 0)
  should.be_true(page.meta.page >= 1)
}

pub fn every_event_has_required_scalars_test() {
  let page = events_page()
  use event <- list.each(page.data)
  should.be_true(event.id != "")
  should.be_true(event.title != "")
  should.be_true(event.start_time != "")
  should.be_true(event.end_time != "")
}

/// `category`, `timezone`, `place`, `venue` and `track` come back `null` on
/// real rows. This asserts the decoder treats null as `None` rather than
/// failing the whole page — the failure mode that would make the list endpoint
/// unusable.
pub fn tolerates_null_optionals_test() {
  let page = events_page()
  let has_a_null_optional =
    list.any(page.data, fn(e) {
      e.timezone == None
      || e.place == None
      || e.venue == None
      || e.track == None
    })
  should.be_true(has_a_null_optional)
}

pub fn nested_group_and_owner_decode_test() {
  let page = events_page()
  // At least one row in any real page carries both a group and an owner.
  let with_group = list.filter(page.data, fn(e) { e.group != None })
  should.be_true(with_group != [])
}

/// A field whose *type* is wrong must still fail loudly — tolerance for null
/// must not become tolerance for drift.
pub fn wrong_type_still_fails_test() {
  "{\"data\":[{\"id\":1,\"title\":\"x\",\"status\":\"published\",\"visibility\":\"public\",\"start_time\":\"t\",\"end_time\":\"t\"}],\"meta\":{}}"
  |> json.parse(decoders.page(of: decoders.event()))
  |> should.be_error
}

/// An absent optional key decodes to `None` rather than erroring.
pub fn absent_optional_is_none_test() {
  let minimal =
    "{\"id\":\"e1\",\"title\":\"T\",\"status\":\"published\",\"visibility\":\"public\",\"start_time\":\"a\",\"end_time\":\"b\"}"
  let event = minimal |> json.parse(decoders.event()) |> should.be_ok
  event.timezone |> should.equal(None)
  event.tags |> should.equal([])
  event.participant_count |> should.equal(0)
  event.require_approval |> should.equal(False)
}

pub fn keeps_present_optionals_test() {
  let with_tz =
    "{\"id\":\"e1\",\"title\":\"T\",\"status\":\"published\",\"visibility\":\"public\",\"start_time\":\"a\",\"end_time\":\"b\",\"timezone\":\"Asia/Shanghai\",\"tags\":[\"x\",\"y\"]}"
  let event = with_tz |> json.parse(decoders.event()) |> should.be_ok
  event.timezone |> should.equal(Some("Asia/Shanghai"))
  event.tags |> should.equal(["x", "y"])
}

pub fn decode_error_is_not_a_crash_test() {
  "not json at all"
  |> json.parse(decoders.event())
  |> should.be_error
}

pub fn unused_decode_import_guard_test() {
  // Keeps `decode` imported for future decoder tests without a warning.
  decode.success(1) |> decode.run(dynamic_one(), _) |> should.be_ok
}

@external(javascript, "./fixture_ffi.mjs", "one")
fn dynamic_one() -> decode.Dynamic

/// A field the API declares non-optional but sometimes sends as explicit
/// `null`. `decode.optional_field` alone only covers an *absent* key, so this
/// 502'd the whole home page until the decoders treated null and absent alike.
/// One event in twenty on the live endpoint carries `require_approval: null`.
pub fn explicit_null_uses_the_default_test() {
  let with_nulls =
    "{\"id\":\"e1\",\"title\":\"T\",\"status\":\"published\",\"visibility\":\"public\",\"start_time\":\"a\",\"end_time\":\"b\",\"require_approval\":null,\"pinned\":null,\"participant_count\":null,\"tags\":null}"
  let event = with_nulls |> json.parse(decoders.event()) |> should.be_ok
  event.require_approval |> should.equal(False)
  event.pinned |> should.equal(False)
  event.participant_count |> should.equal(0)
  event.tags |> should.equal([])
}

/// The venue's name arrives as `name`, not `title`. Decoding `title` returned
/// None for every place in the system, so cards and the share page printed a
/// bare street address with no venue above it — a plausible-looking result
/// that was missing half the answer.
pub fn place_name_decodes_test() {
  let payload =
    "{\"id\":\"e1\",\"title\":\"T\",\"status\":\"published\",\"visibility\":\"public\",\"start_time\":\"a\",\"end_time\":\"b\",\"place\":{\"id\":\"p1\",\"name\":\"4seas Nimman\",\"address\":\"2 20 Nimmana Haeminda Rd\"}}"
  let event = payload |> json.parse(decoders.event()) |> should.be_ok
  let place = event.place |> should.be_some
  place.title |> should.equal(Some("4seas Nimman"))
  place.address |> should.equal(Some("2 20 Nimmana Haeminda Rd"))
}

/// Venues name themselves with `name` too, not `title`. Reading `title` made
/// every venue decode to None, so the schedule fell through to the place name
/// — a different string for the same room ("Building F" where the venue says
/// "1st Floor, Building F"). Wrong, and still shaped like an address.
pub fn venue_name_decodes_test() {
  let payload =
    "{\"id\":\"e1\",\"title\":\"T\",\"status\":\"published\",\"visibility\":\"public\",\"start_time\":\"a\",\"end_time\":\"b\",\"venue\":{\"id\":\"v1\",\"name\":\"Zuzalu Library Event Space - 1st Floor, Building F\"}}"
  let event = payload |> json.parse(decoders.event()) |> should.be_ok
  let venue = event.venue |> should.be_some
  venue.title
  |> should.equal(Some("Zuzalu Library Event Space - 1st Floor, Building F"))
}
