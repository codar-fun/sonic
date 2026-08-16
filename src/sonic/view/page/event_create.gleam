//// Creating an event.
////
//// The fields the form actually collects, and no more. Upstream's draft also
//// carries co-hosts, tickets, recurrence, a map-resolved place and tags; each
//// of those is its own control, and a form that posted empty values for them
//// would write defaults nobody chose.

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
) -> Element(msg) {
  html.div([attribute.class("page-width-sm min-h-[100svh] !pt-4 !pb-12")], [
    html.div([attribute.class("py-6 font-semibold text-center text-xl")], [
      element.text(i18n.t(lang, "Create Event")),
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
        attribute.action("/event/" <> handle(group) <> "/create"),
      ],
      [
        label(i18n.t(lang, "Event Name")),
        text_field("title", "", True),
        label(i18n.t(lang, "Start Time")),
        datetime_field("start_time"),
        label(i18n.t(lang, "End Time")),
        datetime_field("end_time"),
        label(i18n.t(lang, "Timezone")),
        text_field("timezone", zone_of(group), False),
        label(i18n.t(lang, "Online Meeting Link")),
        text_field("meeting_url", "", False),
        label(i18n.t(lang, "Description")),
        html.textarea(
          [
            attribute.name("content"),
            attribute.class(
              "w-full rounded-lg bg-secondary border border-secondary px-3 py-2 min-h-[120px] text-base mb-4",
            ),
          ],
          "",
        ),
        html.div([attribute.class("flex flex-row gap-3 mt-4")], [
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
            [element.text(i18n.t(lang, "Create Event"))],
          ),
        ]),
      ],
    ),
  ])
}

fn label(text: String) -> Element(msg) {
  html.div([attribute.class("font-semibold mb-2 mt-4")], [element.text(text)])
}

fn text_field(name: String, value: String, required: Bool) -> Element(msg) {
  html.input([
    attribute.type_("text"),
    attribute.name(name),
    attribute.value(value),
    attribute.required(required),
    attribute.class(
      "w-full rounded-lg bg-secondary border border-secondary px-3 h-[3rem] text-base",
    ),
  ])
}

/// `datetime-local`, so the browser supplies the picker. The value comes back
/// as `2026-08-20T14:30` — the API wants an instant, so the handler appends
/// the seconds and zone rather than the form pretending to know them.
fn datetime_field(name: String) -> Element(msg) {
  html.input([
    attribute.type_("datetime-local"),
    attribute.name(name),
    attribute.required(True),
    attribute.class(
      "w-full rounded-lg bg-secondary border border-secondary px-3 h-[3rem] text-base",
    ),
  ])
}

fn zone_of(group: GroupDetail) -> String {
  case group.timezone {
    Some(zone) if zone != "" -> zone
    _ -> "UTC"
  }
}

fn handle(group: GroupDetail) -> String {
  case group.name {
    Some(name) if name != "" -> name
    _ -> group.id
  }
}
