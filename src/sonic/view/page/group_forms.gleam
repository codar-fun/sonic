//// The group's own write forms: settings, a new venue, a new programme.
////
//// One module because they are the same shape — a titled column of labelled
//// fields with Cancel and Save — and three near-identical files would drift.
//// Each posts to its own route; the API decides whether this account may.

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{type GroupDetail}
import sonic/i18n.{type Lang}

/// One field: a label, and the control under it.
pub type Field {
  Text(name: String, label: String, value: String, required: Bool)
  Number(name: String, label: String, value: String)
  Area(name: String, label: String, value: String)
}

pub fn view(
  group: GroupDetail,
  lang: Lang,
  title: String,
  action: String,
  submit: String,
  fields: List(Field),
  problem: Option(String),
) -> Element(msg) {
  html.div([attribute.class("page-width-sm min-h-[100svh] !pt-4 !pb-12")], [
    html.div([attribute.class("py-6 font-semibold text-center text-xl")], [
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
      [attribute.method("post"), attribute.action(action)],
      list.append(list.map(fields, fn(field) { control(field, lang) }), [
        html.div([attribute.class("flex flex-row gap-3 mt-6")], [
          html.a(
            [
              attribute.href("/event/" <> handle(group)),
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
            [element.text(i18n.t(lang, submit))],
          ),
        ]),
      ]),
    ),
  ])
}

fn control(field: Field, lang: Lang) -> Element(msg) {
  html.div([], [
    html.div([attribute.class("font-semibold mb-2 mt-4")], [
      element.text(i18n.t(lang, field.label)),
    ]),
    case field {
      Area(name, _, value) ->
        html.textarea(
          [
            attribute.name(name),
            attribute.class(
              "w-full rounded-lg bg-secondary border border-secondary px-3 py-2 min-h-[100px] text-base",
            ),
          ],
          value,
        )
      Number(name, _, value) ->
        html.input([
          attribute.type_("number"),
          attribute.name(name),
          attribute.value(value),
          attribute.attribute("min", "0"),
          attribute.class(
            "w-full rounded-lg bg-secondary border border-secondary px-3 h-[3rem] text-base",
          ),
        ])
      Text(name, _, value, required) ->
        html.input([
          attribute.type_("text"),
          attribute.name(name),
          attribute.value(value),
          attribute.required(required),
          attribute.class(
            "w-full rounded-lg bg-secondary border border-secondary px-3 h-[3rem] text-base",
          ),
        ])
    },
  ])
}

/// The settings form's fields, filled from the group as it stands.
pub fn settings_fields(group: GroupDetail) -> List(Field) {
  [
    Text("nickname", "Group Name", option_text(group.nickname), True),
    Area("bio", "Description", option_text(group.bio)),
    Text("location", "Location", option_text(group.location), False),
  ]
}

pub fn venue_fields() -> List(Field) {
  [
    Text("name", "Venue Name", "", True),
    Area("about", "Description", ""),
    Number("capacity", "Capacity", ""),
  ]
}

pub fn track_fields() -> List(Field) {
  [
    Text("title", "Program Name", "", True),
    Area("description", "Description", ""),
  ]
}

pub fn handle(group: GroupDetail) -> String {
  case group.name {
    Some(name) if name != "" -> name
    _ -> group.id
  }
}

fn option_text(value: Option(String)) -> String {
  case value {
    Some(text) -> text
    None -> ""
  }
}

/// `capacity` is optional and the field may be blank; an unparsable value is
/// left unset rather than defaulted to zero, which would read as "nobody".
pub fn optional_int(value: String) -> Option(Int) {
  case int.parse(value) {
    Ok(n) -> Some(n)
    Error(_) -> None
  }
}
