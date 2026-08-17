//// Awarding a badge.
////
//// One field: who to send it to. The backend matches each receiver by
//// username, wallet address or email, so this does not have to ask which kind
//// of identifier it is being given.

import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{type BadgeClass}
import sonic/i18n.{type Lang}
import sonic/view/image

pub fn view(
  badge_class: BadgeClass,
  lang: Lang,
  problem: Option(String),
  sent: Bool,
) -> Element(msg) {
  html.div([attribute.class("page-width-sm min-h-[100svh] !pt-4 !pb-12")], [
    html.div([attribute.class("py-6 font-semibold text-center text-xl")], [
      element.text(i18n.t(lang, "Send Badge")),
    ]),
    html.div([attribute.class("flex flex-col items-center mb-6")], [
      case badge_class.image_url {
        Some(src) if src != "" ->
          image.square_img(src, 240, "", "w-[120px] h-[120px] rounded-full")
        _ ->
          html.div(
            [attribute.class("w-[120px] h-[120px] rounded-full bg-gray-100")],
            [],
          )
      },
      html.div([attribute.class("font-semibold mt-3")], [
        element.text(option_text(badge_class.title)),
      ]),
    ]),
    case sent {
      True ->
        html.div(
          [
            attribute.class(
              "text-sm bg-[#effff9] text-[#272928] rounded-lg p-3 mb-3",
            ),
          ],
          [element.text(i18n.t(lang, "Badge sent."))],
        )
      False -> element.none()
    },
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
        attribute.action("/badge-class/" <> badge_class.id <> "/send-badge"),
      ],
      [
        html.div([attribute.class("font-semibold mb-2")], [
          element.text(i18n.t(lang, "Receivers")),
        ]),
        html.div([attribute.class("text-xs text-gray-400 mb-2")], [
          element.text(i18n.t(
            lang,
            "One username, wallet address or email per line",
          )),
        ]),
        html.textarea(
          [
            attribute.name("receivers"),
            attribute.required(True),
            attribute.class(
              "w-full rounded-lg bg-secondary border border-secondary px-3 py-2 min-h-[120px] text-base mb-4",
            ),
          ],
          "",
        ),
        html.div([attribute.class("flex flex-row gap-3")], [
          html.a(
            [
              attribute.href("/badge-class/" <> badge_class.id),
              attribute.class(
                "flex-1 h-11 rounded-lg bg-[#f8f9f8] flex items-center justify-center font-semibold",
              ),
            ],
            [element.text(i18n.t(lang, "Cancel"))],
          ),
          html.button(
            [
              attribute.type_("submit"),
              attribute.class(
                "flex-1 h-11 rounded-lg bg-special text-special-foreground font-semibold",
              ),
            ],
            [element.text(i18n.t(lang, "Send Badge"))],
          ),
        ]),
      ],
    ),
  ])
}

fn option_text(value: Option(String)) -> String {
  case value {
    Some(text) -> text
    None -> ""
  }
}
