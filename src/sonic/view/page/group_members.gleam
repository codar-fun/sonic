//// Managing a group's members.
////
//// One row per member: who they are, what role they hold, and the two things
//// that can be done about it. Both actions are form posts rather than links,
//// because both change something — a link that removes a member would be
//// followed by any crawler that finds it.

import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{type GroupDetail, type Membership}
import sonic/i18n.{type Lang}
import sonic/view/image

pub fn view(
  group: GroupDetail,
  members: List(Membership),
  lang: Lang,
  problem: Option(String),
) -> Element(msg) {
  html.div([attribute.class("page-width-sm min-h-[100svh] !pt-4 !pb-12")], [
    html.div([attribute.class("py-6 font-semibold text-center text-xl")], [
      element.text(i18n.t(lang, "Members")),
    ]),
    case problem {
      Some(message) ->
        html.div([attribute.class("text-sm text-[#b91c1c] mb-3")], [
          element.text(message),
        ])
      None -> element.none()
    },
    case members {
      [] ->
        html.div([attribute.class("text-center text-gray-400 py-10")], [
          element.text(i18n.t(lang, "No members yet.")),
        ])
      rows ->
        html.div(
          [],
          list.map(rows, fn(member) { row(group, member, lang) }),
        )
    },
  ])
}

fn row(group: GroupDetail, member: Membership, lang: Lang) -> Element(msg) {
  let is_manager = member.role == Some("manager")
  let is_owner = member.role == Some("owner")

  html.div(
    [
      attribute.class(
        "flex flex-row items-center justify-between py-3 border-b border-[#f1f1f1]",
      ),
    ],
    [
      html.div([attribute.class("flex-row-item-center min-w-0")], [
        case member.user {
          Some(user) ->
            image.avatar_or_default(
              user.image_url,
              user.id,
              64,
              "w-8 h-8 rounded-full mr-2",
            )
          None -> element.none()
        },
        html.div([attribute.class("min-w-0")], [
          html.div([attribute.class("font-semibold text-sm truncate")], [
            element.text(name_of(member)),
          ]),
          html.div([attribute.class("text-xs text-gray-400")], [
            element.text(i18n.t(lang, role_label(member.role))),
          ]),
        ]),
      ]),
      // The owner is not demotable or removable here; upstream moves ownership
      // on its own page, and offering a control that always fails is worse
      // than not offering it.
      case is_owner {
        True -> element.none()
        False ->
          html.div([attribute.class("flex-row-item-center gap-2 shrink-0")], [
            action(
              group,
              member,
              case is_manager {
                True -> "member"
                False -> "manager"
              },
              case is_manager {
                True -> i18n.t(lang, "Remove Manager")
                False -> i18n.t(lang, "Make Manager")
              },
              "bg-[#f8f9f8]",
            ),
            action(
              group,
              member,
              "remove",
              i18n.t(lang, "Remove"),
              "bg-[#f8f9f8] text-[#b91c1c]",
            ),
          ])
      },
    ],
  )
}

/// A form, not a link: these change state, and a link that removes someone is
/// one crawler away from doing it unasked.
fn action(
  group: GroupDetail,
  member: Membership,
  what: String,
  label: String,
  classes: String,
) -> Element(msg) {
  html.form(
    [
      attribute.method("post"),
      attribute.action(
        "/group/" <> handle(group) <> "/management/member",
      ),
      attribute.class("inline"),
    ],
    [
      html.input([
        attribute.type_("hidden"),
        attribute.name("membership"),
        attribute.value(member.id),
      ]),
      html.input([
        attribute.type_("hidden"),
        attribute.name("action"),
        attribute.value(what),
      ]),
      html.button(
        [
          attribute.type_("submit"),
          attribute.class(
            "h-8 px-3 rounded-lg text-xs font-semibold " <> classes,
          ),
        ],
        [element.text(label)],
      ),
    ],
  )
}

fn role_label(role: Option(String)) -> String {
  case role {
    Some("owner") -> "Owner"
    Some("manager") -> "Manager"
    _ -> "Member"
  }
}

fn name_of(member: Membership) -> String {
  case member.user {
    Some(user) ->
      case user.nickname, user.name {
        Some(value), _ if value != "" -> value
        _, Some(value) if value != "" -> value
        _, _ -> user.id
      }
    None -> ""
  }
}

fn handle(group: GroupDetail) -> String {
  case group.name {
    Some(name) if name != "" -> name
    _ -> group.id
  }
}
