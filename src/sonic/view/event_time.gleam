//// Formatting for the ISO-8601 timestamps the API returns.
////
//// Deliberately string-level rather than date-library-backed: the API sends
//// `2023-08-02T07:00:00Z` and the pages here display the date and time as
//// given. Pulling in a full date stack would buy timezone arithmetic that no
//// current page needs, and the moment one does, this module is the single
//// place it goes.

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

/// `2023-08-02T07:00:00Z` → `2 Aug 2023, 07:00`
pub fn readable(iso: String) -> String {
  case split(iso) {
    Some(#(year, month, day, hour, minute)) ->
      int.to_string(day)
      <> " "
      <> month_name(month)
      <> " "
      <> int.to_string(year)
      <> ", "
      <> pad(hour)
      <> ":"
      <> pad(minute)
    None -> iso
  }
}

/// A compact range: same-day events collapse to one date with two times.
pub fn range(start: String, end: String) -> String {
  case split(start), split(end) {
    Some(#(y1, m1, d1, _, _)), Some(#(y2, m2, d2, h2, min2))
      if y1 == y2 && m1 == m2 && d1 == d2
    -> readable(start) <> "–" <> pad(h2) <> ":" <> pad(min2)
    _, _ -> readable(start) <> " → " <> readable(end)
  }
}

/// With the event's timezone appended when the API supplied one.
pub fn range_with_zone(
  start: String,
  end: String,
  zone: Option(String),
) -> String {
  case zone {
    Some(tz) if tz != "" -> range(start, end) <> " (" <> tz <> ")"
    _ -> range(start, end)
  }
}

fn split(iso: String) -> Option(#(Int, Int, Int, Int, Int)) {
  case string.split(iso, "T") {
    [date, time] ->
      case string.split(date, "-"), string.split(time, ":") {
        [y, m, d], [h, min, ..] ->
          case
            int.parse(y),
            int.parse(m),
            int.parse(d),
            int.parse(h),
            int.parse(min)
          {
            Ok(y), Ok(m), Ok(d), Ok(h), Ok(min) -> Some(#(y, m, d, h, min))
            _, _, _, _, _ -> None
          }
        _, _ -> None
      }
    _ -> None
  }
}

fn pad(value: Int) -> String {
  case value < 10 {
    True -> "0" <> int.to_string(value)
    False -> int.to_string(value)
  }
}

fn month_name(month: Int) -> String {
  let names = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov",
    "Dec",
  ]
  case list.drop(names, month - 1) {
    [name, ..] -> name
    [] -> int.to_string(month)
  }
}

/// The event's own clock, not UTC.
///
/// The API sends UTC and names the zone separately. Rendering the UTC time and
/// appending the zone name says the wrong thing — 07:30 "Asia/Bangkok" for an
/// event that starts at 14:30 there. These go through Intl, which carries the
/// tz database; falling back to the raw formatting if the zone is unknown.
pub fn in_zone_date(iso: String, zone: Option(String)) -> String {
  case zone {
    Some(tz) if tz != "" ->
      case format_in_zone(iso, tz, "date") {
        "" -> readable(iso)
        value -> value
      }
    _ -> readable(iso)
  }
}

/// `2024-12-06 14:30` — date and clock together, in the event's zone. The
/// share card prints start and end as two of these rather than as a range.
pub fn in_zone_stamp(iso: String, zone: Option(String)) -> String {
  case zone {
    Some(tz) if tz != "" ->
      case format_in_zone(iso, tz, "stamp") {
        "" -> readable(iso)
        value -> value
      }
    _ -> readable(iso)
  }
}

/// The zone's name and its offset at that instant: `Asia/Bangkok  GMT+7`.
/// Empty when the event carries no zone, so the caller can drop the line
/// rather than print a stray offset.
pub fn zone_line(iso: String, zone: Option(String)) -> String {
  case zone {
    Some(tz) if tz != "" ->
      case zone_label(iso, tz) {
        "" -> tz
        label -> tz <> "  " <> label
      }
    _ -> ""
  }
}

/// `14:30 - 16:00 GMT+7`
pub fn in_zone_range(
  start: String,
  end: String,
  zone: Option(String),
) -> String {
  case zone {
    Some(tz) if tz != "" ->
      case
        format_in_zone(start, tz, "time"),
        format_in_zone(end, tz, "time"),
        zone_label(start, tz)
      {
        "", _, _ -> range(start, end)
        from, to, label -> from <> " - " <> to <> " " <> label
      }
    _ -> range(start, end)
  }
}

@external(javascript, "../../sonic_ffi.mjs", "format_in_zone")
fn format_in_zone(iso: String, zone: String, pattern: String) -> String

@external(javascript, "../../sonic_ffi.mjs", "zone_label")
fn zone_label(iso: String, zone: String) -> String
