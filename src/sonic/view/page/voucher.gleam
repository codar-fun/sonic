//// A badge someone has offered you.
////
//// Opened from a link, so it renders for a signed-out visitor too — they see
//// what is on offer and a prompt to sign in, rather than a redirect that
//// hides what the link was for.

import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{type Voucher}
import sonic/i18n.{type Lang}
import sonic/view/image

pub fn view(
  offer: Voucher,
  lang: Lang,
  signed_in: Bool,
  problem: Option(String),
  done: Option(String),
) -> Element(msg) {
  html.div([attribute.class("page-width-sm min-h-[100svh] !pt-4 !pb-12")], [
    html.div([attribute.class("py-6 font-semibold text-center text-xl")], [
      element.text(i18n.t(lang, "A badge for you")),
    ]),
    html.div([attribute.class("flex flex-col items-center")], [
      case picture(offer) {
        Some(src) ->
          image.square_img(src, 240, "", "w-[120px] h-[120px] rounded-full")
        None ->
          html.div(
            [attribute.class("w-[120px] h-[120px] rounded-full bg-gray-100")],
            [],
          )
      },
      html.div([attribute.class("font-semibold text-lg mt-3")], [
        element.text(title_of(offer)),
      ]),
      case offer.sender {
        Some(who) ->
          html.div([attribute.class("text-sm text-gray-400 mt-1")], [
            element.text(i18n.t(lang, "from") <> " " <> name_of(who)),
          ])
        None -> element.none()
      },
      case offer.message {
        Some(text) if text != "" ->
          html.div([attribute.class("text-sm mt-3 text-center")], [
            element.text(text),
          ])
        _ -> element.none()
      },
    ]),
    html.div([attribute.class("mt-6")], [
      case done {
        Some(message) ->
          html.div(
            [
              attribute.class(
                "text-sm bg-[#effff9] rounded-lg p-3 text-center",
              ),
            ],
            [element.text(message)],
          )
        None ->
          case problem {
            Some(message) ->
              html.div(
                [attribute.class("text-sm text-[#b91c1c] mb-3 text-center")],
                [element.text(message)],
              )
            None -> element.none()
          }
      },
      case done, signed_in {
        Some(_), _ -> element.none()
        // The offer is shown either way; only accepting needs an account.
        None, False ->
          html.a(
            [
              attribute.href("/signin?return=/voucher/" <> offer.id),
              attribute.class(
                "block w-full h-11 rounded-lg bg-special text-special-foreground font-semibold flex items-center justify-center mt-3",
              ),
            ],
            [element.text(i18n.t(lang, "Sign In"))],
          )
        None, True ->
          html.div([attribute.class("flex flex-row gap-3 mt-3")], [
            act(offer, "reject", i18n.t(lang, "Decline"), "bg-[#f8f9f8]"),
            act(
              offer,
              "accept",
              i18n.t(lang, "Accept"),
              "bg-special text-special-foreground",
            ),
          ])
      },
    ]),
  ])
}

fn act(
  offer: Voucher,
  what: String,
  label: String,
  classes: String,
) -> Element(msg) {
  html.form(
    [
      attribute.method("post"),
      attribute.action("/voucher/" <> offer.id),
      attribute.class("flex-1"),
    ],
    [
      html.input([
        attribute.type_("hidden"),
        attribute.name("action"),
        attribute.value(what),
      ]),
      // Only a code-strategy voucher needs this, and then it is in the URL of
      // the link that was shared.
      html.input([
        attribute.type_("hidden"),
        attribute.name("code"),
        attribute.value(""),
      ]),
      html.button(
        [
          attribute.type_("submit"),
          attribute.class(
            "w-full h-11 rounded-lg font-semibold " <> classes,
          ),
        ],
        [element.text(label)],
      ),
    ],
  )
}

fn picture(offer: Voucher) -> Option(String) {
  case offer.badge_class {
    Some(class) -> class.image_url
    None -> None
  }
}

fn title_of(offer: Voucher) -> String {
  case offer.badge_class {
    Some(class) ->
      case class.title {
        Some(text) -> text
        None -> ""
      }
    None -> ""
  }
}

fn name_of(who: types.Profile) -> String {
  case who.nickname, who.name {
    Some(value), _ if value != "" -> value
    _, Some(value) if value != "" -> value
    _, _ -> who.id
  }
}
