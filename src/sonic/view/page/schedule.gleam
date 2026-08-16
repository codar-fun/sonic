//// A group's schedule.
////
//// Three presentations of one fetch. The defining behaviour upstream is
//// grouping by start date: a date heading followed by that day's events, each
//// as a card. Everything else follows from that, so this reproduces the
//// grouping rather than a flat list that merely looks similar.
////
//// The window is a date range, not a page of results: the list view covers
//// the current week, compact and venue a single day. Asking by page count
//// instead returned the group's entire history under a heading that says this
//// week — which is how this page came to be showing hundreds of past events.

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{type Event, type GroupDetail, type Page}
import sonic/router
import sonic/ui/dialog
import sonic/view/event_card
import sonic/view/event_time
import sonic/view/image

/// How a day's events are laid out. The fetch and the grouping are identical
/// across all of these; only this differs, which is why they are one module.
pub type Layout {
  /// One card per event with time, venue and host.
  ListLayout
  /// Title and time only — the embed-sized variant.
  CompactLayout
  /// Grouped by venue within each day.
  VenueLayout
  /// Seven columns, one per weekday.
  WeekLayout
}

pub fn list_view(
  group: GroupDetail,
  anchor: Option(String),
  tags: List(String),
  events: Page(Event),
) -> Element(msg) {
  view(group, anchor, tags, events, ListLayout)
}

pub fn compact_view(
  group: GroupDetail,
  anchor: Option(String),
  tags: List(String),
  events: Page(Event),
) -> Element(msg) {
  view(group, anchor, tags, events, CompactLayout)
}

pub fn venue_view(
  group: GroupDetail,
  anchor: Option(String),
  tags: List(String),
  events: Page(Event),
) -> Element(msg) {
  view(group, anchor, tags, events, VenueLayout)
}

pub fn week_view(
  group: GroupDetail,
  anchor: Option(String),
  tags: List(String),
  events: Page(Event),
) -> Element(msg) {
  view(group, anchor, tags, events, WeekLayout)
}

fn view(
  group: GroupDetail,
  anchor: Option(String),
  tags: List(String),
  events: Page(Event),
  layout: Layout,
) -> Element(msg) {
  html.div(
    [attribute.class("min-h-[100svh] relative pb-12 bg-[#F8F9F8] w-full")],
    [
      html.div([attribute.class("schedule-bg")], []),
      html.div([attribute.class("page-width z-10 relative")], [
        title_row(group),
        tool_bar(group, anchor, tags, layout),
        case layout {
          WeekLayout -> week_grid(group, anchor, events)
          ListLayout ->
            element.fragment([day_nav(group, anchor), body(events, layout)])
          _ -> body(events, layout)
        },
      ]),
    ],
  )
}

fn title_row(group: GroupDetail) -> Element(msg) {
  html.div(
    [
      attribute.class(
        "py-3 sm:py-5 max-w-[100vw] flex flex-row justify-between",
      ),
    ],
    [
      html.div([attribute.class("sm:text-2xl text-xl")], [
        html.a(
          [
            attribute.href("/event/" <> handle(group)),
            attribute.class("font-semibold text-[#6CD7B2] mr-2"),
          ],
          [element.text(display_name(group))],
        ),
        html.span([attribute.class("whitespace-nowrap")], [
          element.text("Event Schedule"),
        ]),
      ]),
    ],
  )
}

/// Month label and the view switcher. Upstream also carries month arrows and a
/// Filter panel; both drive state this page does not hold yet, and a control
/// that visibly does nothing is worse than one that is not there.
fn tool_bar(
  group: GroupDetail,
  anchor: Option(String),
  tags: List(String),
  layout: Layout,
) -> Element(msg) {
  let zone = option.unwrap(group.timezone, "UTC")
  let at = option.unwrap(anchor, "")

  html.div(
    [attribute.class("flex flex-row justify-between items-center flex-wrap")],
    [
      html.div([attribute.class("flex-row-item-center")], [
        html.div(
          [
            attribute.class(
              "schedule-month text-base sm:text-lg mr-2 font-semibold",
            ),
          ],
          [element.text(month_label(zone, at))],
        ),
        // Plain links, not buttons: moving a week is a different URL upstream
        // too (`start_date`), so the arrows work with no runtime and the
        // resulting view is shareable.
        html.div([attribute.class("flex-row-item-center")], [
          step_link(
            group,
            layout,
            schedule_step(zone, view_key(layout), at, -1),
            arrow("uil-angle-left"),
            "w-12",
          ),
          step_link(group, layout, "", today_dot(), "w-8"),
          step_link(
            group,
            layout,
            schedule_step(zone, view_key(layout), at, 1),
            arrow("uil-angle-right"),
            "w-12",
          ),
        ]),
      ]),
      html.div([attribute.class("flex-row-item-center")], [
        filter_panel(group, anchor, tags, layout),
        html.div(
        [
          attribute.class(
            "flex-row-item-center rounded-[8px] bg-[#ececec] py-[5px] px-[5px] ml-4",
          ),
        ],
        list.map(
          [
            #("Compact", "/schedule/compact", CompactLayout, "w-[94px]"),
            #("Venue", "/schedule/venue", VenueLayout, "w-[74px]"),
            #("List", "/schedule/list", ListLayout, "w-[74px]"),
            #("Week", "/schedule/week", WeekLayout, "w-[74px]"),
          ],
          fn(tab) {
            let #(label, path, tab_layout, width) = tab
            switcher_tab(
              label:,
              href: "/event/" <> handle(group) <> path,
              width:,
              active: tab_layout == layout,
            )
          },
        ),
      ),
      ]),
    ],
  )
}

/// The tag filter.
///
/// A real GET form inside the dialog: submitting it is a navigation, so the
/// filtered view has its own URL and works with the runtime absent. The dialog
/// only decides whether the form is on screen.
///
/// The checkbox name is `tags` repeated, and the server also accepts the
/// comma-joined form upstream produces — the same filter arriving by two
/// spellings should not mean two different results.
fn filter_panel(
  group: GroupDetail,
  anchor: Option(String),
  selected: List(String),
  layout: Layout,
) -> Element(msg) {
  let count = list.length(selected)

  dialog.view(
    id: "schedule-filter",
    title: "Filters",
    trigger_label: case count {
      0 -> "Filter"
      n -> "Filter (" <> int.to_string(n) <> ")"
    },
    trigger_class: "font-semibold inline-flex items-center justify-center whitespace-nowrap rounded-lg transition-colors border border-foreground bg-background hover:bg-accent hover:opacity-80 h-11 px-4 py-2 text-base cursor-pointer",
    // Clearing is a navigation to the unfiltered URL, so it belongs in the
    // header as a link — the same place upstream puts it.
    header_action: html.a(
      [
        attribute.href(
          "/event/" <> handle(group) <> "/schedule/" <> view_key(layout),
        ),
        attribute.class("text-[#6CD7B2] font-semibold"),
      ],
      [element.text("Clear All")],
    ),
    body: [
      html.form(
        [
          attribute.method("get"),
          attribute.action(
            "/event/" <> handle(group) <> "/schedule/" <> view_key(layout),
          ),
          attribute.class("flex flex-col min-h-0 flex-1"),
        ],
        [
          // Filtering should not also jump the reader back to this week.
          case anchor {
            Some(date) ->
              html.input([
                attribute.type_("hidden"),
                attribute.name("start_date"),
                attribute.value(date),
              ])
            None -> element.none()
          },
          html.div([attribute.class("px-6 pb-2 font-semibold")], [
            element.text("Tags"),
          ]),
          html.div(
            [attribute.class("px-6 overflow-y-auto flex-1 min-h-0")],
            list.map(group.event_tag_list, fn(tag) {
              tag_row(tag, list.contains(selected, tag))
            }),
          ),
          html.div([attribute.class("flex flex-row gap-3 p-6 pt-4")], [
            // Cancel only closes: it is a label for the dialog's own checkbox,
            // so it discards the ticks without touching the URL.
            html.label(
              [
                attribute.for("schedule-filter"),
                attribute.class(
                  "flex-1 h-11 rounded-lg bg-[#f8f9f8] flex items-center justify-center font-semibold cursor-pointer",
                ),
              ],
              [element.text("Cancel")],
            ),
            html.button(
              [
                attribute.type_("submit"),
                attribute.class(
                  "flex-1 h-11 rounded-lg bg-special text-special-foreground font-semibold",
                ),
              ],
              [element.text("Show Events")],
            ),
          ]),
        ],
      ),
    ],
  )
}

fn tag_row(tag: String, checked: Bool) -> Element(msg) {
  html.label(
    [
      attribute.class(
        "flex flex-row items-center justify-between py-2 cursor-pointer",
      ),
    ],
    [
      html.span([], [element.text(tag)]),
      html.input([
        attribute.type_("checkbox"),
        attribute.name("tags"),
        attribute.value(tag),
        attribute.class("w-5 h-5 accent-[#6CD7B2]"),
        ..case checked {
          True -> [attribute.checked(True)]
          False -> []
        }
      ]),
    ],
  )
}

/// One arrow. An empty date drops the parameter, which is how the middle dot
/// returns to today.
fn step_link(
  group: GroupDetail,
  layout: Layout,
  date: String,
  glyph: Element(msg),
  width: String,
) -> Element(msg) {
  let base = "/event/" <> handle(group) <> "/schedule/" <> view_key(layout)
  html.a(
    [
      attribute.href(case date {
        "" -> base
        value -> base <> "?start_date=" <> value
      }),
      attribute.class(
        "leading-7 h-7 rounded-lg active:scale-95 cursor-pointer hover:bg-gray-200 text-3xl "
        <> width
        <> " flex flex-row justify-center items-center",
      ),
    ],
    [glyph],
  )
}

fn arrow(glyph: String) -> Element(msg) {
  html.i([attribute.class(glyph <> " leading-7")], [])
}

/// A 3px dot, not an icon-font circle: the glyph renders at the surrounding
/// 3xl size and reads as a large ring rather than the reference's small mark.
fn today_dot() -> Element(msg) {
  element.unsafe_raw_html(
    "",
    "span",
    [],
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"28\" height=\"40\" viewBox=\"0 0 28 40\" fill=\"none\">"
      <> "<circle cx=\"14\" cy=\"20\" r=\"3\" fill=\"#272928\"></circle></svg>",
  )
}

fn view_key(layout: Layout) -> String {
  case layout {
    ListLayout -> "list"
    CompactLayout -> "compact"
    VenueLayout -> "venue"
    WeekLayout -> "week"
  }
}

fn switcher_tab(
  label label: String,
  href href: String,
  width width: String,
  active active: Bool,
) -> Element(msg) {
  html.a(
    [
      attribute.href(href),
      attribute.class(
        "font-semibold inline-flex items-center justify-center whitespace-nowrap transition-colors h-9 rounded-[6px] px-3 "
        <> width
        <> case active {
          // The selected tab is a raised white pill; the rest are flat grey.
          True -> " bg-white text-[#272928] shadow"
          False -> " text-[#C3C7C3] hover:text-[#272928]"
        },
      ),
    ],
    [element.text(label)],
  )
}

fn body(events: Page(Event), layout: Layout) -> Element(msg) {
  case events.data {
    [] ->
      html.div([attribute.class("text-center text-gray-400 py-10")], [
        element.text("No events scheduled."),
      ])
    rows ->
      html.div(
        [],
        list.map(event_card.group_by_date(rows), fn(entry) {
          day_block(entry, layout)
        }),
      )
  }
}

/// The sticky day bar. Each cell is an anchor to that day's heading, which
/// already carries the date as its id — so jumping to a day needs no script,
/// and the arrows reuse the same window links as the toolbar.
fn day_nav(group: GroupDetail, anchor: Option(String)) -> Element(msg) {
  let zone = option.unwrap(group.timezone, "UTC")
  let at = option.unwrap(anchor, "")
  let days = schedule_days(zone, "list", at)
  let marked = case at {
    "" -> today_in_zone(zone)
    value -> value
  }

  html.div(
    [
      attribute.class(
        "flex-row-item-center sticky top-[48px] left-0 right-0 z-[999] my-3 sm:my-6 bg-[#F8F9F8]",
      ),
    ],
    [
      step_link(
        group,
        ListLayout,
        schedule_step(zone, "list", at, -1),
        arrow("uil-angle-left"),
        "w-12",
      ),
      html.div(
        [
          attribute.class(
            "flex-row-item-center bg-[#F8F9F8] flex-1 overflow-auto h-[54px] overflow-y-hidden",
          ),
        ],
        list.map(days, fn(day) { day_cell(day, day == marked) }),
      ),
      step_link(
        group,
        ListLayout,
        schedule_step(zone, "list", at, 1),
        arrow("uil-angle-right"),
        "w-12",
      ),
    ],
  )
}

fn day_cell(date: String, selected: Bool) -> Element(msg) {
  // `weekday_label` returns "Mon 10"; the bar prints the number first.
  let #(weekday, number) = case string.split(weekday_label(date), " ") {
    [name, day, ..] -> #(name, day)
    _ -> #("", date)
  }

  html.a(
    [
      attribute.href("#" <> event_time.short_day(date <> "T00:00:00Z")),
      attribute.class(
        "px-8 flex-1 flex-shrink-0 cursor-pointer h-[52px] leading-[52px] text-center sm:border border-[#F1F1F1]",
      ),
      ..case selected {
        True -> [attribute.styles([#("background-color", "#EFFFF9")])]
        False -> []
      }
    ],
    [
      html.strong([], [element.text(number)]),
      html.span([attribute.class("ml-1")], [element.text(weekday)]),
    ],
  )
}

/// Seven columns, one per weekday, each stacking that day's events.
///
/// The days come from the window rather than from the events: deriving them
/// from what came back would drop a quiet Tuesday entirely and shift the rest
/// of the week left.
///
/// Fixed 1000px wide and horizontally scrollable, as upstream — seven readable
/// columns do not fit a phone, and squeezing them to fit makes all seven
/// unreadable instead of six off-screen.
fn week_grid(
  group: GroupDetail,
  anchor: Option(String),
  events: Page(Event),
) -> Element(msg) {
  let days =
    schedule_days(
      option.unwrap(group.timezone, "UTC"),
      "week",
      option.unwrap(anchor, ""),
    )
  let by_day = event_card.group_by_date(events.data)

  html.div([attribute.class("overflow-x-auto pb-4")], [
    html.div([attribute.class("w-[1000px]")], [
      html.div(
        [attribute.class("grid gap-2 grid-cols-7 mt-4 mb-2")],
        list.map(days, fn(day) {
          html.div([attribute.class("text-center font-semibold")], [
            element.text(weekday_label(day)),
          ])
        }),
      ),
      html.div(
        [attribute.class("grid gap-2 grid-cols-7")],
        list.flatten(
          list.index_map(days, fn(day, column) {
            let of_day = case list.key_find(by_day, day) {
              Ok(found) -> found
              Error(_) -> []
            }
            list.index_map(of_day, fn(event, row) {
              week_card(event, column, row)
            })
          }),
        ),
      ),
    ]),
  ])
}

/// Placed explicitly rather than flowed: a CSS grid fills row-major, so an
/// event on Tuesday would otherwise land in whatever cell came next and the
/// columns would stop meaning anything.
fn week_card(event: Event, column: Int, row: Int) -> Element(msg) {
  let area =
    int.to_string(row + 1)
    <> " / "
    <> int.to_string(column + 1)
    <> " / "
    <> int.to_string(row + 2)
    <> " / "
    <> int.to_string(column + 2)

  html.a(
    [
      attribute.href(router.href(router.EventDetail(event.id))),
      attribute.class(
        "bg-white p-2 h-[220px] text-xs scale-100 relative duration-300 cursor-pointer hover:scale-105 hover:z-[999] block overflow-hidden",
      ),
      attribute.styles([
        #("grid-area", area),
        #("box-shadow", "0 1.988px 18px 0 rgba(0, 0, 0, 0.10)"),
      ]),
    ],
    [
      html.div(
        [
          attribute.class("block w-[2px] h-[210px] absolute left-0 top-0"),
          attribute.styles([#("background", track_colour(event))]),
        ],
        [],
      ),
      html.div([attribute.class("font-xs color-[#4F5150] my-1")], [
        element.text(clock_range(event)),
      ]),
      html.div(
        [
          attribute.class(
            "font-semibold text-sm leading-[22px] h-[44px] overflow-hidden webkit-box-clamp-2",
          ),
        ],
        [element.text(event.title)],
      ),
      tag_chips(event.tags),
      host_line(event),
      case where_line(event) {
        Some(name) ->
          html.div(
            [
              attribute.class(
                "absolute right-2 left-2 bottom-2 whitespace-nowrap overflow-hidden overflow-ellipsis",
              ),
            ],
            [element.text(name)],
          )
        None -> element.none()
      },
    ],
  )
}

/// The first tag as a chip, the rest as a count. Upstream does the same: a
/// card is 220px tall and a busy event has five tags.
fn tag_chips(tags: List(String)) -> Element(msg) {
  case tags {
    [] -> element.none()
    [first, ..rest] ->
      html.div([attribute.class("text-xs my-1")], [
        chip(first),
        case list.length(rest) {
          0 -> element.none()
          count -> chip("+" <> int.to_string(count))
        },
      ])
  }
}

fn chip(label: String) -> Element(msg) {
  html.div(
    [
      attribute.class(
        "border border-[#CECED3] inline-flex flex-row flex-nowrap items-center h-[26px] px-2 rounded-3xl m-[2px] !ml-0 max-w-[110px]",
      ),
    ],
    [
      html.span(
        [attribute.class("overflow-ellipsis overflow-hidden whitespace-nowrap")],
        [element.text(label)],
      ),
    ],
  )
}

/// `10:00 - 11:00` — clock only, in the event's zone. The column already says
/// which day it is.
fn clock_range(event: Event) -> String {
  case
    string.split(
      event_time.in_zone_range(event.start_time, event.end_time, event.timezone),
      " ",
    )
  {
    [from, dash, to, ..] -> from <> " " <> dash <> " " <> to
    _ -> ""
  }
}

/// The day heading carries the date as its id, matching upstream — that is
/// what the day navigator scrolls to.
fn day_block(entry: #(String, List(Event)), layout: Layout) -> Element(msg) {
  let label = heading(entry.0)
  html.div([attribute.id(label)], [
    html.div([attribute.class("font-semibold mb-1 mt-6")], [
      element.text(label),
    ]),
    case layout {
      VenueLayout -> html.div([], list.map(by_venue(entry.1), venue_block))
      _ -> html.div([], list.map(entry.1, fn(event) { row(event, layout) }))
    },
  ])
}

/// `2026-08-10` → `Aug 10`. The parser wants a full timestamp, so a grouping
/// key gets a midnight one — the time is discarded either way.
fn heading(date: String) -> String {
  event_time.short_day(date <> "T00:00:00Z")
}

/// Events of one day grouped under their venue, for the venue layout.
fn by_venue(events: List(Event)) -> List(#(String, List(Event))) {
  events
  |> list.fold([], fn(acc, event) {
    let key = venue_name(event)
    case list.key_find(acc, key) {
      Ok(existing) -> list.key_set(acc, key, list.append(existing, [event]))
      Error(_) -> list.append(acc, [#(key, [event])])
    }
  })
}

fn venue_block(entry: #(String, List(Event))) -> Element(msg) {
  html.div([attribute.class("mb-3")], [
    html.div([attribute.class("text-xs font-semibold text-gray-400 mb-1")], [
      element.text(entry.0),
    ]),
    html.div([], list.map(entry.1, fn(event) { row(event, VenueLayout) })),
  ])
}

fn venue_name(event: Event) -> String {
  case where_line(event) {
    Some(name) -> name
    None -> "Unspecified"
  }
}

fn row(event: Event, layout: Layout) -> Element(msg) {
  html.div([attribute.class("flex flex-row text-xs sm:text-base")], [
    html.div([attribute.class("pb-2 flex-1 relative")], [
      html.a(
        [
          attribute.href(router.href(router.EventDetail(event.id))),
          attribute.class(
            "flex flex-col flex-nowrap !items-start bg-white py-2 px-4 shadow rounded-[4px] cursor-pointer relative sm:duration-200 sm:hover:scale-105",
          ),
        ],
        [
          // The track's colour stripe down the left edge. White when the event
          // has no track, which is how upstream renders it too — the stripe is
          // still there, it just does not read as a category.
          html.i(
            [
              attribute.class("h-full w-0.5 left-0 top-0 absolute"),
              attribute.styles([#("background", track_colour(event))]),
            ],
            [],
          ),
          html.div(
            [attribute.class("flex-1 font-semibold mr-4 mb-2 flex-row-item-center")],
            [element.text(event.title)],
          ),
          html.div([attribute.class("flex-1 text-xs text-gray-500 mb-2")], [
            html.i([attribute.class("uil-calender mr-1")], []),
            element.text(time_line(event)),
          ]),
          case layout {
            // The venue layout prints the venue as a heading already, and the
            // compact layout has no room for it.
            ListLayout -> where_element(event)
            _ -> element.none()
          },
          case layout {
            ListLayout -> host_line(event)
            _ -> element.none()
          },
        ],
      ),
    ]),
  ])
}

/// `Aug 10, 10:00 - 11:00 GMT+7` — in the event's own zone, not the server's.
fn time_line(event: Event) -> String {
  event_time.short_day(event.start_time)
  <> ", "
  <> event_time.in_zone_range(event.start_time, event.end_time, event.timezone)
}

fn where_element(event: Event) -> Element(msg) {
  case where_line(event) {
    Some(text) ->
      html.div([attribute.class("flex-1 text-xs text-gray-500 mb-2")], [
        html.i([attribute.class("uil-location-point mr-1")], []),
        element.text(text),
      ])
    None -> element.none()
  }
}

/// The venue's name, or the place's when there is no venue. Upstream prints
/// one name, not both: the venue name already ends in the building it is in.
fn where_line(event: Event) -> Option(String) {
  let venue = case event.venue {
    Some(v) -> first_present([v.title, v.location])
    None -> None
  }
  case venue {
    Some(_) -> venue
    None ->
      case event.place {
        Some(p) -> first_present([p.title, p.address])
        None -> None
      }
  }
}

fn host_line(event: Event) -> Element(msg) {
  case event.owner {
    Some(owner) ->
      html.div([attribute.class("text-xs text-gray-500 flex-row-item-center")], [
        html.div([attribute.class("flex-row-item-center")], [
          element.text("by"),
          image.avatar_or_default(
            owner.image_url,
            owner.id,
            32,
            "w-4 h-4 rounded-full mx-1",
          ),
          element.text(name_of(owner.nickname, owner.name, owner.id)),
        ]),
      ])
    None -> element.none()
  }
}

/// Upstream colours the stripe from the event's track. Tracks carry no colour
/// on this API, so an event with one gets the site's accent and everything else
/// gets white — the same shape, without inventing a palette that would not
/// match anyway.
fn track_colour(event: Event) -> String {
  case event.track {
    Some(_) -> "#6CD7B2"
    None -> "#fff"
  }
}

fn handle(group: GroupDetail) -> String {
  case group.name {
    Some(value) if value != "" -> value
    _ -> group.id
  }
}

fn display_name(group: GroupDetail) -> String {
  case group.nickname, group.name {
    Some(value), _ if value != "" -> value
    _, Some(value) if value != "" -> value
    _, _ -> group.id
  }
}

fn name_of(
  nickname: Option(String),
  name: Option(String),
  fallback: String,
) -> String {
  case first_present([nickname, name]) {
    Some(value) -> value
    None -> fallback
  }
}

fn first_present(values: List(Option(String))) -> Option(String) {
  case values {
    [Some(value), ..] if value != "" -> Some(value)
    [_, ..rest] -> first_present(rest)
    [] -> None
  }
}

@external(javascript, "../../../sonic_ffi.mjs", "month_label")
fn month_label(zone: String, start_date: String) -> String

@external(javascript, "../../../sonic_ffi.mjs", "schedule_days")
fn schedule_days(
  zone: String,
  view: String,
  start_date: String,
) -> List(String)

@external(javascript, "../../../sonic_ffi.mjs", "schedule_step")
fn schedule_step(
  zone: String,
  view: String,
  start_date: String,
  direction: Int,
) -> String

@external(javascript, "../../../sonic_ffi.mjs", "weekday_label")
fn weekday_label(date: String) -> String

@external(javascript, "../../../sonic_ffi.mjs", "today_in_zone")
fn today_in_zone(zone: String) -> String
