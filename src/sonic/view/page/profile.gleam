//// A public profile.

import gleam/option.{type Option, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{type UserProfile}

pub fn view(user: UserProfile) -> Element(msg) {
  html.div([attribute.class("page-width-sm min-h-[100svh] !pt-6 !pb-12")], [
    html.div([attribute.class("flex flex-col items-center")], [
      avatar(user.image_url),
      html.div([attribute.class("text-2xl font-semibold mt-4")], [
        element.text(display_name(user)),
      ]),
      handle(user),
    ]),
    bio(user.bio),
  ])
}

fn avatar(url: Option(String)) -> Element(msg) {
  case url {
    Some(src) if src != "" ->
      html.img([
        attribute.src(src),
        attribute.alt(""),
        attribute.class("w-24 h-24 rounded-full object-cover"),
      ])
    _ -> html.div([attribute.class("w-24 h-24 rounded-full bg-gray-100")], [])
  }
}

fn handle(user: UserProfile) -> Element(msg) {
  case user.name {
    Some(name) if name != "" ->
      html.div([attribute.class("text-sm text-gray-500 mt-1")], [
        element.text("@" <> name),
      ])
    _ -> element.none()
  }
}

fn bio(value: Option(String)) -> Element(msg) {
  case value {
    Some(text) if text != "" ->
      html.div([attribute.class("whitespace-pre-wrap text-sm mt-6")], [
        element.text(text),
      ])
    _ -> element.none()
  }
}

fn display_name(user: UserProfile) -> String {
  case user.nickname, user.name {
    Some(value), _ if value != "" -> value
    _, Some(value) if value != "" -> value
    _, _ -> user.id
  }
}
