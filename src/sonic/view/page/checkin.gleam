//// Checking participants in at an event.
////
//// The attendee list with a button per person. Upstream also scans a QR from
//// a phone camera; that needs a camera permission and a decoder, and the list
//// is what the button behind the scan does anyway.

import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{type Event, type Participant}
import sonic/i18n.{type Lang}
import sonic/view/image

pub fn view(
  event: Event,
  participants: List(Participant),
  lang: Lang,
  problem: Option(String),
) -> Element(msg) {
  html.div([attribute.class("page-width-sm min-h-[100svh] !pt-4 !pb-12")], [
    html.div([attribute.class("py-6 font-semibold text-center text-xl")], [
      element.text(i18n.t(lang, "Check In")),
    ]),
    html.div([attribute.class("text-center text-sm text-gray-400 mb-4")], [
      element.text(event.title),
    ]),
    case problem {
      Some(message) ->
        html.div([attribute.class("text-sm text-[#b91c1c] mb-3")], [
          element.text(message),
        ])
      None -> element.none()
    },
    case participants {
      [] ->
        html.div([attribute.class("text-center text-gray-400 py-10")], [
          element.text(i18n.t(lang, "No one has joined yet.")),
        ])
      rows -> html.div([], list.map(rows, fn(p) { row(event, p, lang) }))
    },
  ])
}

fn row(event: Event, participant: Participant, lang: Lang) -> Element(msg) {
  html.div(
    [
      attribute.class(
        "flex flex-row items-center justify-between py-3 border-b border-[#f1f1f1]",
      ),
    ],
    [
      html.div([attribute.class("flex-row-item-center min-w-0")], [
        case participant.user {
          Some(user) ->
            image.avatar_or_default(
              user.image_url,
              user.id,
              64,
              "w-8 h-8 rounded-full mr-2",
            )
          None -> element.none()
        },
        html.div([attribute.class("font-semibold text-sm truncate")], [
          element.text(name_of(participant)),
        ]),
      ]),
      case participant.user {
        Some(user) ->
          html.form(
            [
              attribute.method("post"),
              attribute.action("/event/checkin/" <> event.id),
            ],
            [
              html.input([
                attribute.type_("hidden"),
                attribute.name("user_id"),
                attribute.value(user.id),
              ]),
              html.button(
                [
                  attribute.type_("submit"),
                  attribute.class(
                    "h-8 px-3 rounded-lg text-xs font-semibold bg-special text-special-foreground",
                  ),
                ],
                [element.text(i18n.t(lang, "Check In"))],
              ),
            ],
          )
        None -> element.none()
      },
    ],
  )
}

fn name_of(participant: Participant) -> String {
  case participant.user {
    Some(user) ->
      case user.nickname, user.name {
        Some(value), _ if value != "" -> value
        _, Some(value) if value != "" -> value
        _, _ -> user.id
      }
    None -> ""
  }
}
