//// Choosing a username.
////
//// A wallet or Google sign-in creates an account with no `name`. Every link
//// to a profile needs one, so this is the step between signing in and being
//// a visible member. Same rules and same shape as the group name form.

import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/i18n.{type Lang}

pub fn view(lang: Lang, taken: String, problem: Option(String)) -> Element(msg) {
  html.div([], [
    html.div(
      [
        attribute.class(
          "absolute left-0 top-0 w-full h-[400px] opacity-[0.3] pointer-events-none",
        ),
        attribute.styles([
          #(
            "background",
            "linear-gradient(180deg, #9efedd, rgba(237, 251, 246, 0))",
          ),
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
            element.text(i18n.t(lang, "Set a unique Social Layer username")),
          ]),
          html.div([attribute.class("text-sm text-gray-500 my-2")], [
            html.ul([attribute.class("pl-4")], [
              rule(i18n.t(
                lang,
                "Contain the English-language letters a-z and the digits 0-9",
              )),
              rule(i18n.t(lang, "Underscores can also be used")),
              rule(i18n.t(lang, "Should be equal or longer than 6 characters")),
            ]),
          ]),
          case problem {
            Some(message) ->
              html.div([attribute.class("text-sm text-[#b91c1c] my-3")], [
                element.text(message),
              ])
            None -> element.none()
          },
          html.form(
            [attribute.method("post"), attribute.action("/register")],
            [
              html.input([
                attribute.type_("text"),
                attribute.name("name"),
                attribute.value(taken),
                attribute.placeholder(i18n.t(lang, "Your username")),
                attribute.required(True),
                attribute.class(
                  "w-full rounded-lg bg-secondary border border-secondary px-3 h-[3rem] text-base my-4",
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
      ],
    ),
  ])
}

fn rule(text: String) -> Element(msg) {
  html.li([attribute.class("list-disc")], [element.text(text)])
}
