//// Badge pages: one issued badge, and one badge class with what it has issued.
////
//// Both are centred single-column pages upstream, narrower than the event
//// pages, so they use `page-width-sm` rather than `page-width`.

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/i18n.{type Lang}
import sonic/api/types.{type Badge, type BadgeClass, type Page, type Profile}
import sonic/view/event_time

/// One issued badge.
pub fn badge(item: Badge) -> Element(msg) {
  html.div([attribute.class("page-width-sm min-h-[100svh] !pt-6 !pb-12")], [
    html.div([attribute.class("flex flex-col items-center")], [
      image(first_present([item.image_url, class_image(item.badge_class)]), 160),
      html.div([attribute.class("text-2xl font-semibold mt-4 text-center")], [
        element.text(title(item)),
      ]),
      byline("Issued to", item.owner),
      byline("Issued by", item.creator),
      issued_on(item.created_at),
    ]),
    content(item.content),
  ])
}

/// A badge class, with the badges minted from it.
pub fn class(
  item: BadgeClass,
  issued: Page(Badge),
  may_send: Bool,
  lang: Lang,
) -> Element(msg) {
  html.div([attribute.class("page-width-sm min-h-[100svh] !pt-6 !pb-12")], [
    html.div([attribute.class("flex flex-col items-center")], [
      image(item.image_url, 160),
      html.div([attribute.class("text-2xl font-semibold mt-4 text-center")], [
        element.text(class_title(item)),
      ]),
      byline("Created by", item.creator),
      html.div([attribute.class("text-sm text-gray-500 mt-1")], [
        element.text(int.to_string(item.counter) <> " issued"),
      ]),
    ]),
    content(item.content),
    holders(issued),
  ])
}

fn holders(issued: Page(Badge)) -> Element(msg) {
  case issued.data {
    [] -> element.none()
    rows ->
      html.div([attribute.class("mt-8")], [
        html.div([attribute.class("font-semibold mb-3")], [
          element.text("Holders"),
        ]),
        html.div(
          [attribute.class("grid grid-cols-2 sm:grid-cols-3 gap-3")],
          list.map(rows, holder),
        ),
      ])
  }
}

fn holder(item: Badge) -> Element(msg) {
  html.a(
    [
      attribute.href("/badge/" <> item.id),
      attribute.class("flex-row-item-center gap-2 rounded-lg p-2 shadow"),
    ],
    [
      avatar(owner_image(item.owner)),
      html.div([attribute.class("text-sm truncate")], [
        element.text(profile_name(item.owner)),
      ]),
    ],
  )
}

fn image(url: Option(String), size: Int) -> Element(msg) {
  let px = int.to_string(size)
  case url {
    Some(src) if src != "" ->
      html.img([
        attribute.src(src),
        attribute.alt(""),
        attribute.class(
          "w-[" <> px <> "px] h-[" <> px <> "px] object-cover rounded-full",
        ),
      ])
    _ ->
      html.div(
        [
          attribute.class(
            "w-[" <> px <> "px] h-[" <> px <> "px] rounded-full bg-gray-100",
          ),
        ],
        [],
      )
  }
}

fn avatar(url: Option(String)) -> Element(msg) {
  case url {
    Some(src) if src != "" ->
      html.img([
        attribute.src(src),
        attribute.alt(""),
        attribute.class("w-8 h-8 rounded-full object-cover shrink-0"),
      ])
    _ ->
      html.div(
        [attribute.class("w-8 h-8 rounded-full bg-gray-100 shrink-0")],
        [],
      )
  }
}

fn byline(label: String, who: Option(Profile)) -> Element(msg) {
  case who {
    Some(_) ->
      html.div([attribute.class("text-sm text-gray-500 mt-1")], [
        element.text(label <> " " <> profile_name(who)),
      ])
    None -> element.none()
  }
}

fn issued_on(created_at: Option(String)) -> Element(msg) {
  case created_at {
    Some(when) if when != "" ->
      html.div([attribute.class("text-sm text-gray-500 mt-1")], [
        element.text(event_time.readable(when)),
      ])
    _ -> element.none()
  }
}

fn content(value: Option(String)) -> Element(msg) {
  case value {
    Some(text) if text != "" ->
      html.div([attribute.class("whitespace-pre-wrap text-sm mt-6")], [
        element.text(text),
      ])
    _ -> element.none()
  }
}

fn title(item: Badge) -> String {
  case first_present([item.title, class_title_opt(item.badge_class)]) {
    Some(value) -> value
    None -> item.id
  }
}

fn class_title(item: BadgeClass) -> String {
  case first_present([item.title, item.name]) {
    Some(value) -> value
    None -> item.id
  }
}

fn class_title_opt(class: Option(BadgeClass)) -> Option(String) {
  case class {
    Some(c) -> first_present([c.title, c.name])
    None -> None
  }
}

fn class_image(class: Option(BadgeClass)) -> Option(String) {
  case class {
    Some(c) -> c.image_url
    None -> None
  }
}

fn owner_image(who: Option(Profile)) -> Option(String) {
  case who {
    Some(p) -> p.image_url
    None -> None
  }
}

fn profile_name(who: Option(Profile)) -> String {
  case who {
    Some(p) ->
      case first_present([p.nickname, p.name]) {
        Some(value) -> value
        None -> p.id
      }
    None -> "someone"
  }
}

fn first_present(values: List(Option(String))) -> Option(String) {
  case values {
    [Some(value), ..] if value != "" -> Some(value)
    [_, ..rest] -> first_present(rest)
    [] -> None
  }
}
