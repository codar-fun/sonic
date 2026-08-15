//// Sign-in.
////
//// Structure from sola.day's `/signin`: a centred card in a viewport-height
//// column, the email field with its envelope glyph and inline Go button, an
//// "or" rule drawn with before/after pseudo-elements, then the alternative
//// methods side by side at `sm`.
////
//// Both steps are plain forms that submit without JavaScript. That is not
//// nostalgia — it means sign-in is exercised by the same SSR route as every
//// other page and cannot break in a way only a browser reveals.

import gleam/option.{type Option, None, Some}
import lustre/attribute.{attribute}
import lustre/element.{type Element}
import lustre/element/html

/// Step one: which address should the code go to.
pub fn ask_email(error: Option(String)) -> Element(msg) {
  shell([
    heading("Sign In"),
    html.form([attribute.method("post"), attribute.action("/signin")], [
      html.div([attribute.class("mb-3")], [
        field(
          glyph: "uil-envelope",
          name: "email",
          type_: "email",
          placeholder: "Email",
          value: "",
          autocomplete: "email",
          action: "Go",
        ),
      ]),
    ]),
    problem(error),
    divider(),
    alternatives(),
  ])
}

/// Step two: the code. The address rides in a hidden field, so nothing
/// half-finished has to be stored or expired on the server.
pub fn ask_code(email: String, error: Option(String)) -> Element(msg) {
  shell([
    heading("Check your email"),
    html.div([attribute.class("text-sm mb-6 text-gray-400")], [
      element.text("We sent a code to " <> email <> "."),
    ]),
    html.form([attribute.method("post"), attribute.action("/signin/verify")], [
      html.input([
        attribute.type_("hidden"),
        attribute.name("email"),
        attribute.value(email),
      ]),
      html.div([attribute.class("mb-3")], [
        field(
          glyph: "uil-lock",
          name: "code",
          type_: "text",
          placeholder: "Code",
          value: "",
          autocomplete: "one-time-code",
          action: "Go",
        ),
      ]),
    ]),
    problem(error),
    html.div([attribute.class("text-sm")], [
      html.a([attribute.href("/signin"), attribute.class("text-[#6cd7b2]")], [
        element.text("Use a different email"),
      ]),
    ]),
  ])
}

/// Vertically centred column, less the 48px header.
fn shell(children: List(Element(msg))) -> Element(msg) {
  html.div([attribute.class("relative")], [
    html.div(
      [
        attribute.class(
          "w-full min-h-[calc(100svh-48px)] flex flex-row justify-center items-center relative z-10",
        ),
      ],
      [
        html.div(
          [attribute.class("max-w-[560px] mx-auto p-4 w-full")],
          children,
        ),
      ],
    ),
  ])
}

fn heading(text: String) -> Element(msg) {
  html.div([attribute.class("font-semibold mb-6 text-xl")], [element.text(text)])
}

/// The bordered field: glyph, input, and an inline submit that reads as a link
/// rather than a button.
fn field(
  glyph glyph: String,
  name name: String,
  type_ type_: String,
  placeholder placeholder: String,
  value value: String,
  autocomplete autocomplete: String,
  action action: String,
) -> Element(msg) {
  html.div(
    [
      attribute.class(
        "inline-flex items-center rounded-lg border focus-within:outline-none focus-within:border-primary bg-secondary border-secondary px-3 h-[3rem] text-base w-full shadow-sm",
      ),
    ],
    [
      html.i([attribute.class(glyph <> " text-2xl text-gray-400")], []),
      html.input([
        attribute.type_(type_),
        attribute.name(name),
        attribute.value(value),
        attribute.placeholder(placeholder),
        attribute.required(True),
        attribute("autocomplete", autocomplete),
        attribute.class("w-full flex-1 h-full bg-transparent outline-none mx-1"),
      ]),
      html.button(
        [
          attribute.type_("submit"),
          attribute.title("Sign In"),
          attribute.class(
            "flex flex-row items-center gap-1 pl-2 cursor-pointer text-sm font-medium whitespace-nowrap",
          ),
        ],
        [
          element.text(action),
          html.i([attribute.class("uil-arrow-right text-2xl")], []),
        ],
      ),
    ],
  )
}

/// The "or" rule, drawn with pseudo-elements exactly as upstream does.
fn divider() -> Element(msg) {
  html.div(
    [
      attribute.class(
        "flex flex-row items-center mb-3 after:content-[''] after:block after:flex-1 after:bg-secondary after:h-[1px] before:block before:flex-1 before:bg-secondary before:h-[1px]",
      ),
    ],
    [html.div([attribute.class("mx-2 text-sm")], [element.text("or")])],
  )
}

/// Google and wallet sign-in are separate flows that are not built. The
/// buttons are rendered as upstream draws them — including its icons — rather
/// than greyed out: a disabled-looking control changes the page's appearance,
/// and matching it is the requirement. Pressing one does nothing yet.
fn alternatives() -> Element(msg) {
  html.div([attribute.class("flex flex-col sm:grid sm:gap-2 sm:grid-cols-2")], [
    alternative(google_mark(), "Google Auth"),
    alternative(
      html.i([attribute.class("uil-wallet text-xl")], []),
      "Ethereum Wallet",
    ),
  ])
}

fn alternative(icon: Element(msg), label: String) -> Element(msg) {
  html.button(
    [
      attribute.type_("button"),
      attribute.class(
        "font-semibold inline-flex items-center whitespace-nowrap rounded-lg ring-offset-background transition-colors border border-foreground bg-background hover:bg-accent hover:opacity-80 h-11 px-4 py-2 w-full justify-center gap-3 font-normal shadow-sm mb-3 sm:mb-0",
      ),
    ],
    [icon, element.text(label)],
  )
}

/// Google's mark, in its own colours — a monochrome stand-in reads as a
/// different button.
fn google_mark() -> Element(msg) {
  element.unsafe_raw_html(
    "",
    "span",
    [attribute.class("inline-flex shrink-0")],
    "<svg width=\"18\" height=\"18\" viewBox=\"0 0 18 18\" xmlns=\"http://www.w3.org/2000/svg\"><path fill=\"#4285f4\" d=\"M17.64 9.2c0-.638-.057-1.251-.164-1.84H9v3.481h4.844a4.14 4.14 0 0 1-1.796 2.716v2.259h2.908c1.702-1.567 2.684-3.874 2.684-6.615\"/><path fill=\"#34a853\" d=\"M9 18c2.43 0 4.467-.806 5.956-2.18l-2.908-2.259c-.806.54-1.837.86-3.048.86-2.344 0-4.328-1.583-5.036-3.71H.957v2.332A8.997 8.997 0 0 0 9 18\"/><path fill=\"#fbbc05\" d=\"M3.964 10.712A5.41 5.41 0 0 1 3.682 9c0-.593.102-1.17.282-1.71V4.958H.957A8.997 8.997 0 0 0 0 9c0 1.452.348 2.827.957 4.042z\"/><path fill=\"#ea4335\" d=\"M9 3.58c1.321 0 2.508.454 3.44 1.345l2.582-2.58C13.464.891 11.428 0 9 0A8.997 8.997 0 0 0 .957 4.958L3.964 7.29C4.672 5.163 6.656 3.58 9 3.58\"/></svg>",
  )
}

fn problem(error: Option(String)) -> Element(msg) {
  case error {
    Some(message) ->
      html.div([attribute.class("text-sm text-[#b91c1c] mb-3")], [
        element.text(message),
      ])
    None -> element.none()
  }
}
