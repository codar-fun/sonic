//// The global event list.
////
//// Not a route seastar-app has — its events live under a group or a detail
//// page — so there is no upstream layout to copy. It uses the same card and
//// date grouping as the group home rather than a look of its own, because a
//// second style for the same object is how two pages start disagreeing about
//// what an event looks like.

import gleam/int
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{type Event, type Page}
import sonic/view/event_card

pub fn view(page: Page(Event)) -> Element(msg) {
  html.div([attribute.class("page-width min-h-[100svh] !pt-4 !pb-12")], [
    html.h2(
      [
        attribute.class(
          "text-2xl font-semibold mb-3 md:flex-row flex items-center justify-between flex-col",
        ),
      ],
      [
        html.div([], [element.text("Events")]),
        html.div([attribute.class("text-sm text-gray-500")], [
          element.text(int.to_string(page.meta.total) <> " events"),
        ]),
      ],
    ),
    event_card.list(page),
  ])
}
