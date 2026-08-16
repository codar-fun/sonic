//// The site footer.
////
//// Ported from `components/Footer.tsx`. Two columns on wide screens, stacked
//// and centred on narrow ones — the alignment classes flip at `sm`, so a
//// version that only got the desktop arrangement right would centre wrongly
//// on a phone.
////
//// Upstream draws its wordmark as an inline SVG; the same asset is already
//// served as a file here, so it is an <img> rather than 40 lines of paths.

import lustre/attribute.{attribute}
import lustre/element.{type Element}
import lustre/element/html

pub fn view() -> Element(msg) {
  html.div(
    [
      attribute.class(
        "mt-20 sm:flex-row flex-col flex p-4 border-gray-500 sm:justify-between justify-center",
      ),
      attribute.styles([#("border-top", "1px solid #f1f1f1")]),
    ],
    [links(), feedback()],
  )
}

fn links() -> Element(msg) {
  html.div([attribute.class("flex flex-col justify-center sm:justify-start")], [
    html.div(
      [attribute.class("flex-row-item-center justify-center sm:justify-start")],
      [
        // The footer mark is the icon alone, not the horizontal lockup the
        // header uses.
        html.img([
          attribute.src("/static/images/icon.svg"),
          attribute.alt("Social Layer"),
          attribute.width(39),
          attribute.height(27),
        ]),
        link("https://www.sociallayer.im/", "About us"),
        link("mailto:hi@sola.day", "Contact us"),
        link(issues_url, "Feedback"),
      ],
    ),
    // Second row: the OAuth developer pages. Those routes are not built here
    // yet, so these link where upstream links and will land on the 404 page
    // until they are — visible and honest, rather than a row that is silently
    // missing from the footer.
    html.div(
      [attribute.class("flex-row-item-center justify-center sm:justify-start mt-2")],
      [
        html.a([attribute.href("/oauth/apps")], [element.text("Developer")]),
        link("/oauth/grants", "Authorized Applications"),
      ],
    ),
  ])
}

fn feedback() -> Element(msg) {
  html.div(
    [attribute.class("flex flex-col sm:mt-0 mt-3 items-center sm:items-start")],
    [
      html.div([attribute.class("mb-2 text-sm")], [
        element.text("We value your feedback!"),
      ]),
      html.div([attribute.class("flex-row-item-center justify-start")], [
        icon_link("/remember", "Remember", "uil-award"),
        icon_link("https://warpcast.com/sociallayer", "Warpcast", "uil-comment"),
        icon_link("https://t.me/sociallayer_im", "Telegram", "uil-telegram"),
        icon_link(issues_url, "GitHub", "media-github"),
      ]),
    ],
  )
}

const issues_url = "https://github.com/sociallayer-im/seastar-app/issues"

fn link(href: String, label: String) -> Element(msg) {
  html.a([attribute.href(href), attribute.class("ml-3")], [element.text(label)])
}

/// External links open in a new tab upstream; `rel` is added here because
/// `target="_blank"` without it hands the opened page a reference back.
fn icon_link(href: String, title: String, glyph: String) -> Element(msg) {
  html.a(
    [
      attribute.href(href),
      attribute.title(title),
      attribute.class("mr-2"),
      attribute("target", "_blank"),
      attribute("rel", "noopener noreferrer"),
    ],
    [html.i([attribute.class(glyph <> " text-xl")], [])],
  )
}
