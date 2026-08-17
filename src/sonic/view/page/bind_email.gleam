//// Attaching an email address to an account signed in by wallet.
////
//// Two steps, like sign-in: ask for the address, then for the code sent to
//// it. Both are plain forms.

import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/i18n.{type Lang}

pub fn ask_email(lang: Lang, problem: Option(String)) -> Element(msg) {
  shell(lang, "Bind Email", problem, [
    field("email", "email", i18n.t(lang, "Email"), ""),
  ])
}

pub fn ask_code(
  lang: Lang,
  email: String,
  problem: Option(String),
) -> Element(msg) {
  shell(lang, "Check your email", problem, [
    html.div([attribute.class("text-sm text-gray-400 mb-3")], [
      element.text(i18n.t(lang, "We sent a code to") <> " " <> email <> "."),
    ]),
    html.input([
      attribute.type_("hidden"),
      attribute.name("email"),
      attribute.value(email),
    ]),
    field("code", "text", i18n.t(lang, "Code"), ""),
  ])
}

fn shell(
  lang: Lang,
  title: String,
  problem: Option(String),
  body: List(Element(msg)),
) -> Element(msg) {
  html.div(
    [
      attribute.class(
        "w-full min-h-[calc(100svh-48px)] flex flex-row justify-center items-center",
      ),
    ],
    [
      html.div([attribute.class("w-full max-w-[500px] mx-auto p-4")], [
        html.div([attribute.class("font-semibold text-2xl mb-4")], [
          element.text(i18n.t(lang, title)),
        ]),
        case problem {
          Some(message) ->
            html.div([attribute.class("text-sm text-[#b91c1c] mb-3")], [
              element.text(message),
            ])
          None -> element.none()
        },
        html.form(
          [attribute.method("post"), attribute.action("/bind-email")],
          [
            html.div([], body),
            html.button(
              [
                attribute.type_("submit"),
                attribute.class(
                  "w-full h-11 rounded-lg bg-special text-special-foreground font-semibold mt-4",
                ),
              ],
              [element.text(i18n.t(lang, "Confirm"))],
            ),
          ],
        ),
      ]),
    ],
  )
}

fn field(
  name: String,
  type_: String,
  placeholder: String,
  value: String,
) -> Element(msg) {
  html.input([
    attribute.type_(type_),
    attribute.name(name),
    attribute.value(value),
    attribute.placeholder(placeholder),
    attribute.required(True),
    attribute.class(
      "w-full rounded-lg bg-secondary border border-secondary px-3 h-[3rem] text-base",
    ),
  ])
}
