//// Sign-in, in two steps: ask for an address, then for the code sent to it.
////
//// Both steps are plain forms that work without JavaScript. That is not
//// nostalgia — it means the sign-in path is exercised by the same SSR route
//// everything else uses, so it cannot break in a way only a browser reveals.

import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

/// Step one: which address should the code go to.
pub fn ask_email(error: Option(String)) -> Element(msg) {
  html.div([], [
    html.h1([], [element.text("Sign in")]),
    html.p([attribute.class("muted")], [
      element.text("We'll email you a one-time code. No password."),
    ]),
    problem(error),
    html.form([attribute.method("post"), attribute.action("/signin")], [
      html.label([attribute.class("field")], [
        html.span([], [element.text("Email")]),
        html.input([
          attribute.type_("email"),
          attribute.name("email"),
          attribute.required(True),
          attribute.autofocus(True),
          attribute.placeholder("you@example.com"),
        ]),
      ]),
      html.button([attribute.type_("submit")], [element.text("Send code")]),
    ]),
  ])
}

/// Step two: the code. The address travels in a hidden field so this step is
/// stateless on the server — no half-finished sign-in to store or expire.
pub fn ask_code(email: String, error: Option(String)) -> Element(msg) {
  html.div([], [
    html.h1([], [element.text("Check your email")]),
    html.p([attribute.class("muted")], [
      element.text("We sent a code to " <> email <> "."),
    ]),
    problem(error),
    html.form([attribute.method("post"), attribute.action("/signin/verify")], [
      html.input([
        attribute.type_("hidden"),
        attribute.name("email"),
        attribute.value(email),
      ]),
      html.label([attribute.class("field")], [
        html.span([], [element.text("Code")]),
        html.input([
          attribute.type_("text"),
          attribute.name("code"),
          attribute.required(True),
          attribute.autofocus(True),
          attribute.attribute("inputmode", "numeric"),
          attribute.attribute("autocomplete", "one-time-code"),
        ]),
      ]),
      html.button([attribute.type_("submit")], [element.text("Sign in")]),
    ]),
    html.p([attribute.class("meta")], [
      html.a([attribute.href("/signin")], [element.text("Use a different email")]),
    ]),
  ])
}

fn problem(error: Option(String)) -> Element(msg) {
  case error {
    Some(message) ->
      html.p([attribute.class("problem")], [element.text(message)])
    None -> element.none()
  }
}
