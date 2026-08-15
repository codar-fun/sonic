//// The browser entry point.
////
//// Mounts Lustre onto markup the server already rendered. Lustre's client
//// runtime builds its initial vdom with `virtualise(root)`, so it adopts the
//// existing DOM rather than replacing it — that is what makes one set of view
//// functions serve both sides.
////
//// Only interactive regions are mounted, not the whole page. A static page
//// needs no runtime, and attaching one to everything would pay for reactivity
//// nobody asked for.

import gleam/option
import lustre
import lustre/element.{type Element}
import sonic/ui/menu
import sonic/view/layout

pub fn main() -> Nil {
  // Each interactive region is an independent app keyed by a selector. Missing
  // ones are not an error: pages carry different regions, and a page without a
  // menu should not log a failure.
  mount_menu()
  // Not a Lustre app: the share buttons act on the page and hold no state, and
  // running a runtime over the card would re-render the very thing the page
  // exists to have screenshotted.
  wire_share_buttons()
  // The dialogs are CSS-only; Escape is the one behaviour CSS cannot express.
  wire_dialog_escape()
  wire_signin_return()
  wire_wallet_signin()
  Nil
}

fn mount_menu() -> Nil {
  let app = lustre.simple(init, update, view)
  case lustre.start(app, "#account-menu", Nil) {
    Ok(_) -> Nil
    Error(_) -> Nil
  }
}

pub type Model {
  Model(open: Bool, signed_in: Bool)
}

pub type Msg {
  Toggled
  Dismissed
}

fn init(_flags) -> Model {
  // The server renders the trigger with a data attribute saying whether there
  // is a session; reading it back avoids a second source of truth in JS.
  Model(open: False, signed_in: signed_in_flag())
}

fn update(model: Model, msg: Msg) -> Model {
  case msg {
    Toggled -> Model(..model, open: !model.open)
    Dismissed -> Model(..model, open: False)
  }
}

fn view(model: Model) -> Element(Msg) {
  menu.view(
    open: model.open,
    label: layout.menu_label(model.signed_in),
    on_toggle: option.Some(Toggled),
    on_dismiss: option.Some(Dismissed),
    // Same source as the server render, so the two cannot disagree.
    items: layout.menu_items(model.signed_in),
  )
}

@external(javascript, "../sonic_client_ffi.mjs", "signed_in_flag")
fn signed_in_flag() -> Bool

@external(javascript, "../sonic_client_ffi.mjs", "wire_share_buttons")
fn wire_share_buttons() -> Nil

@external(javascript, "../sonic_client_ffi.mjs", "wire_dialog_escape")
fn wire_dialog_escape() -> Nil

@external(javascript, "../sonic_client_ffi.mjs", "wire_signin_return")
fn wire_signin_return() -> Nil

@external(javascript, "../sonic_client_ffi.mjs", "wire_wallet_signin")
fn wire_wallet_signin() -> Nil
