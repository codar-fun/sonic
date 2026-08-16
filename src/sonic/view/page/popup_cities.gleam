//// Every pop-up city, at /popup-city.
////
//// The home page shows a slice of these and links here for the rest; that
//// link pointed at a route that did not exist, so it was a 404 shipped on the
//// front page. Cards are the same ones the home page draws, so the two cannot
//// drift.

import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{type PopupCity}
import sonic/i18n.{type Lang}
import sonic/view/popup_card

pub fn view(cities: List(PopupCity), lang: Lang) -> Element(msg) {
  html.div([attribute.class("relative")], [
    html.div(
      [attribute.class("page-width min-h-[100svh] pt-0 sm:pt-6 !pb-16")],
      [
        html.h2(
          [
            attribute.class(
              "text-2xl font-semibold mb-3 md:flex-row flex items-center justify-between flex-col",
            ),
          ],
          [element.text(i18n.t(lang, "Pop-up Cities"))],
        ),
        case cities {
          [] ->
            html.div([attribute.class("text-center text-gray-400 py-10")], [
              element.text(i18n.t(lang, "No events yet.")),
            ])
          rows ->
            html.div(
              [
                attribute.class(
                  "grid md:grid-cols-4 sm:grid-cols-3 grid-cols-2 gap-2",
                ),
              ],
              list.map(rows, popup_card.view),
            )
        },
      ],
    ),
  ])
}
