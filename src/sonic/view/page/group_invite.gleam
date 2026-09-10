//// Inviting people to a group.
////
//// One receiver per line and a role, matching how badges are sent — the
//// backend resolves each line against username, wallet address and email, so
//// the form does not ask which kind it is being given.

import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{type GroupDetail}
import sonic/i18n.{type Lang}

pub fn view(
  group: GroupDetail,
  lang: Lang,
  problem: Option(String),
  sent: Bool,
) -> Element(msg) {
  html.div([attribute.class("page-width-sm min-h-[100svh] !pt-4 !pb-12")], [
    html.div([attribute.class("py-6 font-semibold text-center text-xl")], [
      element.text(i18n.t(lang, "Invite Members")),
    ]),
    case sent {
      True ->
        html.div(
          [attribute.class("text-sm bg-[#effff9] rounded-lg p-3 mb-3")],
          [element.text(i18n.t(lang, "Invitations sent."))],
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
        attribute.action(
          "/group/" <> handle(group) <> "/management/invite",
        ),
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
        html.div([attribute.class("font-semibold mb-2")], [
          element.text(i18n.t(lang, "Role")),
        ]),
        html.select(
          [
            attribute.name("role"),
            attribute.class(
              "w-full rounded-lg bg-secondary border border-secondary px-3 h-[3rem] text-base mb-4",
            ),
          ],
          list.map([#("member", "Member"), #("manager", "Manager")], fn(pair) {
            html.option([attribute.value(pair.0)], i18n.t(lang, pair.1))
          }),
        ),
        html.div([attribute.class("flex flex-row gap-3")], [
          html.a(
            [
              attribute.href("/group/" <> handle(group) <> "/management/member"),
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
            [element.text(i18n.t(lang, "Send Invitations"))],
          ),
        ]),
      ],
    ),
  ])
}

fn handle(group: GroupDetail) -> String {
  case group.name {
    Some(name) if name != "" -> name
    _ -> group.id
  }
}
