//// Editing your own profile.
////
//// A plain form that submits without JavaScript, like sign-in. The social
//// links section is rendered because it is part of the page's shape, but each
//// row's Edit opens a per-network dialog upstream and the values live in a
//// `social_links` object this client does not model yet — so those rows are
//// shown and marked, rather than wired to a control that would silently drop
//// what was typed.

import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{type UserProfile}
import sonic/view/image

pub fn view(user: UserProfile, problem: Option(String)) -> Element(msg) {
  html.div([attribute.class("page-width-sm min-h-[100svh] !pt-4 !pb-12")], [
    html.div([attribute.class("py-6 font-semibold text-center text-xl")], [
      element.text("Edit Profile"),
    ]),
    case problem {
      Some(message) ->
        html.div([attribute.class("text-sm text-[#b91c1c] mb-3")], [
          element.text(message),
        ])
      None -> element.none()
    },
    html.form(
      [
        attribute.method("post"),
        attribute.action("/profile/" <> handle(user) <> "/edit"),
      ],
      [
        section("Avatar"),
        avatar_panel(user),
        section("Nickname"),
        html.input([
          attribute.type_("text"),
          attribute.name("nickname"),
          attribute.value(option_text(user.nickname)),
          attribute.placeholder("Nickname"),
          attribute.attribute("maxlength", "30"),
          attribute.class(
            "w-full rounded-lg bg-secondary border border-secondary px-3 h-[3rem] text-base mb-4",
          ),
        ]),
        section("Bio"),
        html.textarea(
          [
            attribute.name("bio"),
            attribute.placeholder("Bio"),
            attribute.class(
              "w-full rounded-lg bg-secondary border border-secondary px-3 py-2 min-h-[80px] text-base mb-4",
            ),
          ],
          option_text(user.bio),
        ),
        section("Social Links"),
        social_links(),
        html.div([attribute.class("flex flex-row gap-3 mt-6")], [
          html.a(
            [
              attribute.href("/profile/" <> handle(user)),
              attribute.class(
                "flex-1 h-11 rounded-lg bg-[#f8f9f8] flex items-center justify-center font-semibold",
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
            [element.text("Save")],
          ),
        ]),
      ],
    ),
  ])
}

fn section(title: String) -> Element(msg) {
  html.div([attribute.class("font-semibold mb-2 mt-4")], [element.text(title)])
}

/// Upload needs multipart and an upload service; neither is built, so the
/// panel shows the current picture and says so rather than offering a button
/// that cannot finish.
fn avatar_panel(user: UserProfile) -> Element(msg) {
  html.div(
    [
      attribute.class(
        "bg-secondary rounded-lg py-6 flex flex-col items-center mb-4",
      ),
    ],
    [
      image.avatar_or_default(
        user.image_url,
        user.id,
        200,
        "w-[100px] h-[100px] rounded-full",
      ),
      html.div([attribute.class("text-xs text-gray-400 mt-3")], [
        element.text("Uploading a new picture is not available yet"),
      ]),
    ],
  )
}

fn social_links() -> Element(msg) {
  html.div(
    [attribute.class("flex flex-col gap-2")],
    list.map(
      ["X", "Github", "Discord", "ENS", "Lens", "Nostr", "Telegram"],
      fn(name) {
        html.div(
          [
            attribute.class(
              "flex flex-row items-center justify-between bg-secondary rounded-lg px-3 h-11",
            ),
          ],
          [
            html.div([], [element.text(name)]),
            html.div([attribute.class("text-xs text-gray-400")], [
              element.text("Not editable yet"),
            ]),
          ],
        )
      },
    ),
  )
}

fn handle(user: UserProfile) -> String {
  case user.name {
    Some(name) if name != "" -> name
    _ -> user.id
  }
}

fn option_text(value: Option(String)) -> String {
  case value {
    Some(text) -> text
    None -> ""
  }
}
