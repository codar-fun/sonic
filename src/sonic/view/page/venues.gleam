//// A group's venues.
////
//// One card per venue: picture, name, description, capacity and address —
//// the same shape upstream renders. The venues arrive inside the group, so
//// this page makes no request of its own.

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{type GroupDetail, type VenueDetail}
import sonic/i18n.{type Lang}
import sonic/view/image

pub fn view(group: GroupDetail, lang: Lang) -> Element(msg) {
  html.div([attribute.class("page-width-sm min-h-[100svh] !pt-4 !pb-12")], [
    html.div([attribute.class("flex-row-item-center justify-between mb-4")], [
      html.a(
        [
          attribute.href("/event/" <> group_handle(group)),
          attribute.class("text-[#6cd7b2]"),
        ],
        [element.text("← Back")],
      ),
      html.div([attribute.class("font-semibold text-xl")], [
        element.text(i18n.t(lang, "Venues")),
      ]),
      // Balances the row so the title stays centred against the Back link.
      html.div([attribute.class("w-[48px]")], []),
    ]),
    case group.venues {
      [] ->
        html.div([attribute.class("text-center text-gray-400 py-10")], [
          element.text(i18n.t(lang, "No venues yet.")),
        ])
      rows -> html.div([], list.map(rows, fn(venue) { card(venue, lang) }))
    },
  ])
}

fn card(venue: VenueDetail, lang: Lang) -> Element(msg) {
  html.div([attribute.class("bg-white rounded-lg shadow p-4 mb-3")], [
    case picture(venue) {
      Some(src) ->
        image.square_img(src, 320, "", "w-[160px] h-[160px] rounded-lg mb-3")
      None -> element.none()
    },
    html.div([attribute.class("font-semibold")], [
      element.text(option_text(venue.name)),
    ]),
    case venue.about {
      Some(text) if text != "" ->
        html.div(
          [attribute.class("text-gray-400 text-sm my-2 whitespace-pre-line")],
          [element.text(text)],
        )
      _ -> element.none()
    },
    html.div([attribute.class("text-sm mt-2")], [
      element.text(
        i18n.t(lang, "Capacity")
        <> ": "
        <> case venue.capacity {
          Some(n) -> int.to_string(n)
          None -> "Unlimited"
        },
      ),
    ]),
    html.div([attribute.class("text-sm")], [
      element.text(i18n.t(lang, "Address") <> ": " <> address(venue)),
    ]),
  ])
}

/// `featured_image_url` is null on every venue the API returns; the picture
/// that exists is the first of `image_urls`.
fn picture(venue: VenueDetail) -> Option(String) {
  case venue.featured_image_url, venue.image_urls {
    Some(src), _ if src != "" -> Some(src)
    _, [src, ..] -> Some(src)
    _, [] -> None
  }
}

fn address(venue: VenueDetail) -> String {
  case venue.place {
    Some(place) -> option_text(place.address)
    None -> ""
  }
}

fn group_handle(group: GroupDetail) -> String {
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
