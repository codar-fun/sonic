//// The document shell every page is wrapped in.
////
//// Structure and class names are copied from seastar-app's `(normal)/layout.tsx`
//// and `components/Header.tsx` rather than reinvented: matching the original is
//// the requirement, and using its classes makes any divergence show up as a
//// diff instead of as a subtly different pixel.

import gleam/option
import lustre/attribute.{attribute}
import lustre/element.{type Element}
import lustre/element/html
import sonic/ui/menu

pub fn document(body: Element(msg), signed_in: Bool) -> Element(msg) {
  html.html([attribute("lang", "en")], [
    html.head([], [
      html.meta([attribute("charset", "utf-8")]),
      // Matches the original's viewport exactly, including the deliberate
      // maximum-scale/user-scalable choice.
      html.meta([
        attribute("name", "viewport"),
        attribute(
          "content",
          "width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no",
        ),
      ]),
      html.title([], "Social Layer"),
      html.link([
        attribute.rel("icon"),
        attribute.type_("image/svg+xml"),
        attribute.href("/static/images/logo_horizontal.svg"),
      ]),
      html.link([
        attribute.rel("stylesheet"),
        attribute.href("/static/app.css"),
      ]),
      // Native ESM: the Gleam output is already modules, so it is served as
      // built rather than bundled. Deferred so it cannot block first paint —
      // the page works without it.
      html.script(
        [
          attribute.type_("module"),
          attribute.src("/static/js/sonic/client_entry.mjs"),
        ],
        "",
      ),
    ]),
    html.body([attribute.class("antialiased")], [
      html.div([attribute.class("min-h-[100svh]")], [
        header(signed_in),
        html.div([attribute.class("relative")], [body]),
      ]),
    ]),
  ])
}

/// The site header. Sticky by default, as in the original — only the schedule
/// pages opt out, and those do not exist here yet.
///
/// `signed_in` reports whether a session cookie was *sent*, not whether it is
/// still valid: validating would cost an API call on every render. A stale
/// token shows the signed-in header and the first API call that needs it fails
/// loudly, rather than silently degrading to anonymous.
fn header(signed_in: Bool) -> Element(msg) {
  html.header(
    [
      attribute.class(
        "w-full h-[48px] shadow bg-[var(--background)] sticky top-0 z-[999]",
      ),
    ],
    [
      html.div(
        [
          attribute.class(
            "page-width w-full flex-row-item-center justify-between items-center h-[48px]",
          ),
        ],
        [nav(signed_in), account(signed_in)],
      ),
    ],
  )
}

fn nav(signed_in: Bool) -> Element(msg) {
  html.div([attribute.class("flex-row-item-center")], [
    html.a([attribute.href("/"), attribute.class("sm:block hidden")], [
      html.img([
        attribute.src("/static/images/logo_horizontal.svg"),
        attribute.width(102),
        attribute.height(32),
        attribute.alt("Social Layer"),
      ]),
    ]),
    html.a([attribute.href("/"), attribute.class("sm:hidden block")], [
      html.img([
        attribute.src("/static/images/sola_logo_compact.png"),
        attribute.width(32),
        attribute.height(32),
        attribute.alt("Social Layer"),
      ]),
    ]),
    html.a(
      [
        attribute.href("/discover"),
        attribute.class("ml-3 text-xs font-semibold"),
      ],
      [element.text("Discover")],
    ),
    case signed_in {
      True ->
        html.a(
          [
            attribute.href("/my-events/attended"),
            attribute.class("ml-3 text-xs font-semibold"),
          ],
          [element.text("My Events")],
        )
      False -> element.none()
    },
  ])
}

fn account(signed_in: Bool) -> Element(msg) {
  html.div([attribute.class("flex-row-item-center text-xs relative")], [
    // A plain GET form, so search works without JavaScript exactly as the
    // rest of the site does.
    html.form(
      [
        attribute.method("get"),
        attribute.action("/search"),
        attribute.class("flex-row-item-center"),
      ],
      [
        html.input([
          attribute.type_("search"),
          attribute.name("keyword"),
          attribute.placeholder("Search"),
          attribute.class(
            "text-xs px-2 py-1 rounded border border-gray-200 w-[120px] sm:w-[160px]",
          ),
        ]),
      ],
    ),
    html.span([attribute.class("w-[0.5px] h-3 bg-gray-400 mx-2")], []),
    // Rendered server-side in its closed state and hydrated in place, so the
    // menu is usable markup before the bundle arrives rather than a hole. The
    // session state is stamped on the mount point so the client has one source
    // of truth for it rather than two.
    html.div(
      [
        attribute.id("account-menu"),
        attribute("data-signed-in", case signed_in {
          True -> "true"
          False -> "false"
        }),
      ],
      [
        menu.view(
          open: False,
          label: menu_label(signed_in),
          on_toggle: option.None,
          on_dismiss: option.None,
          items: menu_items(signed_in),
        ),
      ],
    ),
  ])
}

pub fn menu_label(signed_in: Bool) -> String {
  case signed_in {
    True -> "Account"
    False -> "Sign In"
  }
}

pub fn menu_items(signed_in: Bool) -> List(#(String, String)) {
  case signed_in {
    True -> [#("My Events", "/events"), #("Sign Out", "/signout")]
    False -> [#("Sign In", "/signin")]
  }
}
