//// Search results.
////
//// Four independent result sets for one keyword, each rendered only when it
//// has something — an empty "Badges" heading tells the reader nothing except
//// that the section exists.

import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{
  type BadgeClass, type Event, type Group, type SearchResults, type UserProfile,
}
import sonic/router
import sonic/view/event_time

pub fn view(keyword: String, results: SearchResults) -> Element(msg) {
  let sections =
    [
      section("Events", list.map(results.events, event_row)),
      section("Groups", list.map(results.groups, group_row)),
      section("People", list.map(results.users, user_row)),
      section("Badges", list.map(results.badge_classes, badge_row)),
    ]
    |> list.filter(fn(el) { el != element.none() })

  html.div([attribute.class("page-width min-h-[100svh] !pt-4 !pb-12")], [
    html.form([attribute.method("get"), attribute.action("/search")], [
      html.input([
        attribute.type_("search"),
        attribute.name("keyword"),
        attribute.value(keyword),
        attribute.placeholder("Search events, groups, people"),
        attribute.class(
          "w-full max-w-[480px] px-3 py-2 rounded-lg border border-gray-200",
        ),
      ]),
    ]),
    case sections {
      [] ->
        html.div([attribute.class("text-center text-gray-400 py-10")], [
          element.text(case keyword {
            "" -> "Type something to search."
            _ -> "Nothing matched “" <> keyword <> "”."
          }),
        ])
      _ -> html.div([], sections)
    },
  ])
}

fn section(title: String, rows: List(Element(msg))) -> Element(msg) {
  case rows {
    [] -> element.none()
    _ ->
      html.div([attribute.class("mt-6")], [
        html.div([attribute.class("font-semibold mb-2")], [element.text(title)]),
        html.div([], rows),
      ])
  }
}

fn event_row(event: Event) -> Element(msg) {
  row(
    router.href(router.EventDetail(event.id)),
    event.title,
    Some(event_time.range(event.start_time, event.end_time)),
  )
}

fn group_row(group: Group) -> Element(msg) {
  row(
    "/event/" <> option_or(group.name, group.id),
    display(group.nickname, group.name, group.id),
    None,
  )
}

fn user_row(user: UserProfile) -> Element(msg) {
  row(
    "/profile/" <> option_or(user.name, user.id),
    display(user.nickname, user.name, user.id),
    None,
  )
}

fn badge_row(badge: BadgeClass) -> Element(msg) {
  row(
    "/badge-class/" <> badge.id,
    display(badge.title, badge.name, badge.id),
    None,
  )
}

fn row(href: String, title: String, meta: Option(String)) -> Element(msg) {
  html.a(
    [
      attribute.href(href),
      attribute.class(
        "block p-3 rounded-lg mb-2 shadow hover:shadow-md transition-shadow bg-[var(--background)]",
      ),
    ],
    [
      html.div([attribute.class("font-semibold truncate")], [
        element.text(title),
      ]),
      case meta {
        Some(text) ->
          html.div([attribute.class("text-xs text-gray-500 mt-1")], [
            element.text(text),
          ])
        None -> element.none()
      },
    ],
  )
}

fn display(
  first: Option(String),
  second: Option(String),
  fallback: String,
) -> String {
  case first, second {
    Some(value), _ if value != "" -> value
    _, Some(value) if value != "" -> value
    _, _ -> fallback
  }
}

fn option_or(value: Option(String), fallback: String) -> String {
  case value {
    Some(text) if text != "" -> text
    _ -> fallback
  }
}
