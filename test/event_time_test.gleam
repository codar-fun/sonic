//// Time formatting tests, including the malformed input the API has not sent
//// yet. A formatter that throws on an unexpected timestamp would take down a
//// whole page for one bad row, so the contract is: never fail, fall back to
//// showing the raw value.

import gleam/option.{None, Some}
import gleeunit/should
import sonic/view/event_time

pub fn formats_a_real_timestamp_test() {
  event_time.readable("2023-08-02T07:00:00Z")
  |> should.equal("2 Aug 2023, 07:00")
}

pub fn pads_single_digit_times_test() {
  event_time.readable("2024-01-09T05:07:00Z")
  |> should.equal("9 Jan 2024, 05:07")
}

pub fn december_is_not_off_by_one_test() {
  event_time.readable("2024-12-31T23:59:00Z")
  |> should.equal("31 Dec 2024, 23:59")
}

/// Same-day events collapse to one date and two times rather than repeating
/// the date, which is how the upstream app reads.
pub fn same_day_range_collapses_test() {
  event_time.range("2023-08-02T07:00:00Z", "2023-08-02T07:45:00Z")
  |> should.equal("2 Aug 2023, 07:00–07:45")
}

pub fn multi_day_range_shows_both_dates_test() {
  event_time.range("2023-08-02T07:00:00Z", "2023-08-04T09:30:00Z")
  |> should.equal("2 Aug 2023, 07:00 → 4 Aug 2023, 09:30")
}

/// Same day-of-month in a different month must not collapse.
pub fn same_day_number_different_month_test() {
  event_time.range("2023-08-02T07:00:00Z", "2023-09-02T09:00:00Z")
  |> should.equal("2 Aug 2023, 07:00 → 2 Sep 2023, 09:00")
}

pub fn timezone_is_appended_when_present_test() {
  event_time.range_with_zone(
    "2023-08-02T07:00:00Z",
    "2023-08-02T07:45:00Z",
    Some("Asia/Shanghai"),
  )
  |> should.equal("2 Aug 2023, 07:00–07:45 (Asia/Shanghai)")
}

/// `timezone` is null on real rows, so this is the common case, not the edge.
pub fn absent_timezone_is_omitted_test() {
  event_time.range_with_zone(
    "2023-08-02T07:00:00Z",
    "2023-08-02T07:45:00Z",
    None,
  )
  |> should.equal("2 Aug 2023, 07:00–07:45")
}

pub fn empty_timezone_is_omitted_test() {
  event_time.range_with_zone(
    "2023-08-02T07:00:00Z",
    "2023-08-02T07:45:00Z",
    Some(""),
  )
  |> should.equal("2 Aug 2023, 07:00–07:45")
}

/// Malformed input must degrade to the raw string, never crash the page.
pub fn malformed_falls_back_to_raw_test() {
  event_time.readable("not a timestamp") |> should.equal("not a timestamp")
  event_time.readable("") |> should.equal("")
  event_time.readable("2023-08-02") |> should.equal("2023-08-02")
}

pub fn malformed_range_still_renders_test() {
  event_time.range("garbage", "2023-08-02T07:45:00Z")
  |> should.equal("garbage → 2 Aug 2023, 07:45")
}
