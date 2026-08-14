//// Entry point. Runs the SSR server; `--smoke` instead performs a single live
//// API call and reports what came back, which is how the transport gets
//// verified against the real service rather than against a mock.

import gleam/int
import gleam/io
import gleam/javascript/promise
import gleam/list
import gleam/option.{None}
import gleam/string
import sonic/api/event
import sonic/api/types.{DecodeError, HttpError, NetworkError}
import sonic/server

pub fn main() -> Nil {
  case argv() {
    ["--smoke", ..] -> smoke()
    _ -> server.start(port: 3000)
  }
}

/// One real request against api.sola.day, printing enough to tell a working
/// transport from a working-looking one.
fn smoke() -> Nil {
  io.println("GET " <> event.calendar_url("<id>") |> string.replace("/calendar.ics", "") )
  let _ = {
    use result <- promise.map(event.first_page(limit: 3, auth: None))
    case result {
      Ok(page) -> {
        io.println(
          "ok: "
          <> int.to_string(list.length(page.data))
          <> " events of "
          <> int.to_string(page.meta.total)
          <> " total",
        )
        list.each(page.data, fn(e) { io.println("  - " <> e.title) })
      }
      Error(HttpError(status, body)) ->
        io.println(
          "http " <> int.to_string(status) <> ": " <> string.slice(body, 0, 200),
        )
      Error(DecodeError(detail)) -> io.println("decode failed: " <> detail)
      Error(NetworkError(detail)) -> io.println("network failed: " <> detail)
    }
  }
  Nil
}

@external(javascript, "./sonic_ffi.mjs", "argv")
fn argv() -> List(String)
