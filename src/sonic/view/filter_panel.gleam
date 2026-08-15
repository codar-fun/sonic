//// The group page's filter panel.
////
//// Ported from the sidebar block on sola.day's group page: `mt-6 hidden
//// sm:block` — it is desktop-only upstream, where mobile reaches the same
//// filters through the funnel button in the search row.
////
//// The controls are readonly inputs with a dropdown attached, exactly as
//// upstream renders them. Opening those dropdowns and applying the filter is
//// client behaviour that is not wired up yet, so the panel currently shows the
//// unfiltered state ("All Programs", "All Venues", "All Time"). Rendering it
//// closed and inert matches what a visitor sees before the page's JavaScript
//// runs there too.

import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn view() -> Element(msg) {
  html.div([attribute.class("mt-6 hidden sm:block")], [
    header(),
    select("Programs", "All Programs"),
    select("Kind", "Select Kind"),
    select("Repeating", "Select Repeating"),
    time_range(),
    select("Venues", "All Venues"),
  ])
}

fn header() -> Element(msg) {
  html.div([attribute.class("flex-row-item-center justify-between mb-4")], [
    html.div([attribute.class("font-semibold text-2xl")], [
      element.text("Filter"),
    ]),
    html.button(
      [
        attribute.class(
          "font-semibold inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-lg ring-offset-background transition-colors hover:bg-secondary hover:text-accent-foreground h-9 px-3 !font-normal text-sm text-primary-foreground",
        ),
      ],
      [element.text("Reset Filter")],
    ),
  ])
}

/// A labelled dropdown. `readonly` is upstream's: the value is chosen from the
/// list, never typed.
fn select(label: String, value: String) -> Element(msg) {
  html.div([attribute.class("my-3 text-sm")], [
    html.div([attribute.class("font-semibold mb-1")], [element.text(label)]),
    html.div([attribute.class("dropwdown relative")], [
      html.div(
        [
          attribute.class(
            "inline-flex items-center rounded-lg border focus-within:outline-none focus-within:border-primary bg-secondary border-secondary px-3 h-[3rem] text-base cursor-pointer w-full",
          ),
        ],
        [
          html.input([
            attribute.type_("text"),
            attribute.class(
              "w-full flex-1 h-full bg-transparent outline-none mx-1 cursor-pointer",
            ),
            attribute.readonly(True),
            attribute.value(value),
          ]),
          html.i([attribute.class("uil-angle-down text-lg")], []),
        ],
      ),
    ]),
  ])
}

/// Time range is buttons rather than a dropdown upstream.
fn time_range() -> Element(msg) {
  let base =
    "font-semibold inline-flex items-center justify-center whitespace-nowrap rounded-lg border border-foreground bg-background hover:bg-accent hover:opacity-80 h-9 px-3 mr-1 text-xs"

  html.div([attribute.class("my-3 text-sm")], [
    html.div([attribute.class("font-semibold mb-1")], [
      element.text("Time Range"),
    ]),
    html.div(
      [attribute.class("flex-row-item-center !flex-wrap gap-1")],
      list.map(["All Time", "Today"], fn(label) {
        html.button([attribute.class(base)], [element.text(label)])
      }),
    ),
  ])
}
