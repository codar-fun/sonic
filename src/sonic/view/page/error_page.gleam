//// What a visitor sees when a page cannot be produced.
////
//// The upstream detail is shown rather than hidden: this is a developer-facing
//// app during the rewrite, and a 502 that says which shape failed to decode is
//// worth far more than a polite apology.

import gleam/int
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn view(status: Int, message: String) -> Element(msg) {
  html.div([attribute.class("err")], [
    html.h1([], [element.text(title(status))]),
    html.p([attribute.class("muted")], [element.text(message)]),
    html.p([], [html.a([attribute.href("/")], [element.text("Back to events")])]),
  ])
}

fn title(status: Int) -> String {
  case status {
    404 -> "Not found"
    403 -> "Not public"
    502 -> "Upstream problem"
    _ -> int.to_string(status)
  }
}
