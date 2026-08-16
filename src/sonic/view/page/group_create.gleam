//// Creating a group.
////
//// A handle and nothing else: upstream asks only for the name here and takes
//// you to the group's own settings afterwards. The three rules are spelled
//// out above the field because the name is permanent — it becomes the URL.

import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/i18n.{type Lang}

pub fn view(lang: Lang, taken: String, problem: Option(String)) -> Element(msg) {
  html.div([], [
    // The wash behind the form, as upstream draws it.
    html.div(
      [
        attribute.class(
          "absolute left-0 top-0 w-full h-[400px] opacity-[0.3] pointer-events-none",
        ),
        attribute.styles([
          #("background", "linear-gradient(180deg, #9efedd, rgba(237, 251, 246, 0))"),
        ]),
      ],
      [],
    ),
    html.div(
      [
        attribute.class(
          "w-full min-h-[calc(100svh-48px)] flex flex-row justify-center items-center relative z-10",
        ),
      ],
      [
        html.div([attribute.class("w-full max-w-[500px] mx-auto p-4")], [
          html.div([attribute.class("font-semibold text-2xl")], [
            element.text(i18n.t(lang, "Set a unique group name")),
          ]),
          html.div([attribute.class("text-sm text-gray-500 my-2")], [
            html.ul(
              [attribute.class("pl-4")],
              [
                rule(i18n.t(
                  lang,
                  "Contain the English-language letters a-z and the digits 0-9",
                )),
                rule(i18n.t(
                  lang,
                  "Hyphens can also be used but it can not be used at the beginning and at the end",
                )),
                rule(i18n.t(
                  lang,
                  "Should be equal or longer than 6 characters",
                )),
              ],
            ),
          ]),
          html.div([attribute.class("my-4")], [
            case problem {
              Some(message) ->
                html.div([attribute.class("text-sm text-[#b91c1c] mb-3")], [
                  element.text(message),
                ])
              None -> element.none()
            },
            html.form(
              [attribute.method("post"), attribute.action("/group/create")],
              [
                html.input([
                  attribute.type_("text"),
                  attribute.name("name"),
                  attribute.value(taken),
                  attribute.placeholder(i18n.t(lang, "Group name")),
                  attribute.required(True),
                  attribute.class(
                    "w-full rounded-lg bg-secondary border border-secondary px-3 h-[3rem] text-base mb-4",
                  ),
                ]),
                html.button(
                  [
                    attribute.type_("submit"),
                    attribute.class(
                      "w-full h-11 rounded-lg bg-special text-special-foreground font-semibold",
                    ),
                  ],
                  [element.text(i18n.t(lang, "Confirm"))],
                ),
              ],
            ),
          ]),
        ]),
      ],
    ),
  ])
}

fn rule(text: String) -> Element(msg) {
  html.li([attribute.class("list-disc")], [element.text(text)])
}
