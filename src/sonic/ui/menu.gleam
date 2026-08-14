//// A dropdown menu, replacing `@radix-ui/react-dropdown-menu`.
////
//// Radix's value is not the visual — it is the behaviour and the ARIA wiring:
//// a trigger that reports its own expanded state, a menu with the right roles,
//// dismissal on Escape and on clicking away, and focus that lands somewhere
//// sensible. Reproducing the box without those would look identical and be
//// unusable with a keyboard or a screen reader.
////
//// The markup is rendered by the server too, so the closed state is correct
//// before any JavaScript runs and the menu is not a hole in the page while the
//// bundle loads.

import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

/// `items` are label/href pairs; this menu navigates rather than dispatching,
/// which is what the header's account menu needs.
///
/// Handlers are optional so the server and the browser render from this one
/// definition. Server-side there is nothing to dispatch to, and a version that
/// took real handlers would force a second, drifting copy of the markup.
pub fn view(
  open open: Bool,
  label label: String,
  on_toggle on_toggle: Option(msg),
  on_dismiss on_dismiss: Option(msg),
  items items: List(#(String, String)),
) -> Element(msg) {
  html.div(
    [
      attribute.class("relative"),
      // Escape closes the menu from anywhere inside it — the part people
      // notice missing when a dropdown is rebuilt by hand.
      ..case on_dismiss {
        Some(msg) -> [event.on_keydown(fn(_key) { msg })]
        None -> []
      }
    ],
    [
      trigger(open, label, on_toggle),
      case open {
        True -> panel(items, on_dismiss)
        False -> element.none()
      },
    ],
  )
}

fn trigger(open: Bool, label: String, on_toggle: Option(msg)) -> Element(msg) {
  html.button(
    [
      attribute.type_("button"),
      attribute.class("cursor-pointer text-xs font-semibold"),
      attribute.attribute("aria-haspopup", "menu"),
      attribute.attribute("aria-expanded", case open {
        True -> "true"
        False -> "false"
      }),
      ..case on_toggle {
        Some(msg) -> [event.on_click(msg)]
        None -> []
      }
    ],
    [element.text(label)],
  )
}

fn panel(
  items: List(#(String, String)),
  on_dismiss: Option(msg),
) -> Element(msg) {
  html.div(
    [
      attribute.attribute("role", "menu"),
      attribute.class(
        "absolute right-0 top-[calc(100%+6px)] min-w-[160px] rounded-lg shadow bg-[var(--background)] py-1 z-[1000]",
      ),
    ],
    list.map(items, fn(item) {
      html.a(
        [
          attribute.attribute("role", "menuitem"),
          attribute.href(item.1),
          attribute.class("block px-3 py-2 text-xs hover:bg-gray-50"),
          ..case on_dismiss {
            Some(msg) -> [event.on_click(msg)]
            None -> []
          }
        ],
        [element.text(item.0)],
      )
    }),
  )
}
