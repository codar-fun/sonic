//// The document shell every page is wrapped in.
////
//// Styles are inlined rather than pulled from a CDN so a rendered page is
//// self-contained and testable offline — the SSR output can be asserted on
//// without a network round trip for assets.

import lustre/attribute.{attribute}
import lustre/element.{type Element}
import lustre/element/html

pub fn document(body: Element(msg), signed_in: Bool) -> Element(msg) {
  html.html([attribute("lang", "en")], [
    html.head([], [
      html.meta([attribute("charset", "utf-8")]),
      html.meta([
        attribute("name", "viewport"),
        attribute("content", "width=device-width, initial-scale=1"),
      ]),
      html.title([], "sonic"),
      html.link([
        attribute.rel("stylesheet"),
        attribute.href("/static/app.css"),
      ]),
    ]),
    html.body([], [
      header(signed_in),
      html.main([attribute.class("wrap")], [body]),
    ]),
  ])
}

/// The header reports whether a session cookie was *sent*, not whether it is
/// still valid — validating it would cost an API call on every page render.
/// A stale token shows "Sign out", and the first API call that needs it will
/// fail loudly rather than silently degrading to anonymous.
fn header(signed_in: Bool) -> Element(msg) {
  html.header([attribute.class("bar")], [
    html.a([attribute.href("/"), attribute.class("brand")], [
      element.text("sonic"),
    ]),
    case signed_in {
      True ->
        html.a([attribute.href("/signout"), attribute.class("session")], [
          element.text("Sign out"),
        ])
      False ->
        html.a([attribute.href("/signin"), attribute.class("session")], [
          element.text("Sign in"),
        ])
    },
  ])
}
