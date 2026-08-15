//// A modal dialog, replacing `@radix-ui/react-dialog`.
////
//// Radix's value is the behaviour, not the box: a dialog that is only a
//// styled div is announced as nothing, cannot be dismissed with Escape, and
//// leaves the page behind it reachable. So this carries `role="dialog"`,
//// `aria-modal`, a labelled title, a backdrop that dismisses on click, and
//// Escape handling (wired by the client FFI).
////
//// Open state is a checkbox, not a client model. The dialogs here hold
//// server-rendered content — a group's tag list, a form — and a Lustre app
//// over them would have to receive that content a second time to re-render
//// it, which is two sources of truth for one list. The checkbox means the
//// dialog opens, closes and submits with no runtime at all.

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn view(
  id id: String,
  title title: String,
  trigger_label trigger_label: String,
  trigger_class trigger_class: String,
  header_action header_action: Element(msg),
  body body: List(Element(msg)),
) -> Element(msg) {
  let title_id = id <> "-title"

  html.div([attribute.class("relative")], [
    // The state. Hidden, and the only thing that decides whether the panel is
    // on screen — `peer-checked` below reads it.
    html.input([
      attribute.type_("checkbox"),
      attribute.id(id),
      attribute.class("peer hidden"),
    ]),
    html.label(
      [
        attribute.for(id),
        attribute.class(trigger_class),
        attribute.attribute("role", "button"),
        attribute.attribute("tabindex", "0"),
        attribute.attribute("aria-haspopup", "dialog"),
      ],
      [html.span([], [element.text(trigger_label)])],
    ),
    html.div(
      [
        attribute.class(
          "hidden peer-checked:flex fixed inset-0 z-[9999] items-center justify-center",
        ),
      ],
      [
        // The backdrop is a label for the same checkbox, so clicking away
        // closes the dialog without a line of script.
        html.label(
          [attribute.for(id), attribute.class("absolute inset-0 bg-black/30")],
          [],
        ),
        html.div(
          [
            attribute.attribute("role", "dialog"),
            attribute.attribute("aria-modal", "true"),
            // Points at the heading, so the dialog is announced by name rather
            // than as an unlabelled region.
            attribute.attribute("aria-labelledby", title_id),
            attribute.class(
              "relative bg-white rounded-lg shadow-lg w-[520px] max-w-[92vw] max-h-[86vh] flex flex-col",
            ),
          ],
          [
            html.div(
              [
                attribute.class(
                  "flex flex-row items-center justify-between px-6 pt-6 pb-2",
                ),
              ],
              [
                html.div(
                  [
                    attribute.id(title_id),
                    attribute.class("text-xl font-semibold"),
                  ],
                  [element.text(title)],
                ),
                header_action,
              ],
            ),
            ..body
          ],
        ),
      ],
    ),
  ])
}
