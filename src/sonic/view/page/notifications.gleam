//// Notifications.
////
//// The backend calls these activities and orders them newest first. Each row
//// says who did what; `action` is a machine string like `voucher/send_badge`,
//// so it is turned into a sentence here rather than shown raw.

import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{type Activity}
import sonic/i18n.{type Lang}
import sonic/view/event_time
import sonic/view/image

pub fn view(activities: List(Activity), lang: Lang) -> Element(msg) {
  html.div([attribute.class("page-width-sm min-h-[100svh] !pt-4 !pb-12")], [
    html.div([attribute.class("py-6 font-semibold text-center text-xl")], [
      element.text(i18n.t(lang, "Notifications")),
    ]),
    case activities {
      [] ->
        html.div([attribute.class("text-center text-gray-400 py-10")], [
          element.text(i18n.t(lang, "Nothing here yet.")),
        ])
      rows -> html.div([], list.map(rows, fn(a) { row(a, lang) }))
    },
  ])
}

fn row(activity: Activity, lang: Lang) -> Element(msg) {
  html.div(
    [
      attribute.class(
        "flex flex-row items-start py-3 border-b border-[#f1f1f1] "
        // Unread rows are tinted, as upstream does — the only thing `has_read`
        // is for.
        <> case activity.has_read {
          True -> ""
          False -> "bg-[#f7fffc]"
        },
      ),
    ],
    [
      case activity.initiator {
        Some(who) ->
          image.avatar_or_default(
            who.image_url,
            who.id,
            64,
            "w-8 h-8 rounded-full mr-2 shrink-0",
          )
        None -> element.none()
      },
      html.div([attribute.class("min-w-0 flex-1")], [
        html.div([attribute.class("text-sm")], [
          element.text(sentence(activity, lang)),
        ]),
        case activity.created_at {
          Some(when) ->
            html.div([attribute.class("text-xs text-gray-400 mt-1")], [
              element.text(event_time.readable(when)),
            ])
          None -> element.none()
        },
      ]),
    ],
  )
}

/// `voucher/send_badge` is not a sentence. Unknown actions fall through to the
/// raw string rather than to nothing: a notification nobody can read still
/// beats a blank row that hides that something happened.
fn sentence(activity: Activity, lang: Lang) -> String {
  let who = case activity.initiator {
    Some(person) ->
      case person.nickname, person.name {
        Some(value), _ if value != "" -> value
        _, Some(value) if value != "" -> value
        _, _ -> person.id
      }
    None -> ""
  }

  let what = case activity.action {
    "voucher/send_badge"
    | "voucher/send_badge_by_address"
    | "voucher/send_badge_by_email" -> i18n.t(lang, "sent you a badge")
    "voucher/create" -> i18n.t(lang, "created a badge voucher")
    "voucher/use" -> i18n.t(lang, "claimed a badge")
    "badge/transfer" -> i18n.t(lang, "transferred a badge")
    "badge/swap" -> i18n.t(lang, "swapped a badge")
    "badge/burn" -> i18n.t(lang, "burned a badge")
    "group_invite/send" -> i18n.t(lang, "invited you to a group")
    "group_invite/update_role" -> i18n.t(lang, "changed your role in a group")
    "remember/join" -> i18n.t(lang, "joined a shared badge")
    "remember/mint" -> i18n.t(lang, "minted a shared badge")
    "updated" -> i18n.t(lang, "updated an event")
    "cancelled" -> i18n.t(lang, "cancelled an event")
    other -> other
  }

  case who {
    "" -> what
    name -> name <> " " <> what
  }
}
