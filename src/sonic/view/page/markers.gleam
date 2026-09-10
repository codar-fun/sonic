//// A group's map points.
////
//// Rendered as a list, not a map. Upstream draws these on Google Maps, which
//// needs an API key this deployment does not have; a map that cannot load its
//// tiles is a grey rectangle, whereas the same points as a list are readable
//// and every one still links to its own page.

import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{type GroupDetail, type Marker}
import sonic/i18n.{type Lang}
import sonic/view/image

pub fn list_view(
  group: GroupDetail,
  markers: List(Marker),
  lang: Lang,
) -> Element(msg) {
  html.div([attribute.class("page-width-sm min-h-[100svh] !pt-4 !pb-12")], [
    html.div([attribute.class("py-6 font-semibold text-center text-xl")], [
      element.text(i18n.t(lang, "Map")),
    ]),
    case markers {
      [] ->
        html.div([attribute.class("text-center text-gray-400 py-10")], [
          element.text(i18n.t(lang, "Nothing here yet.")),
        ])
      rows -> html.div([], list.map(rows, card))
    },
  ])
}

fn card(marker: Marker) -> Element(msg) {
  html.a(
    [
      attribute.href("/marker/detail/" <> marker.id),
      attribute.class(
        "flex flex-row items-start p-3 mb-3 rounded-lg shadow hover:shadow-md transition-shadow",
      ),
    ],
    [
      case marker.cover_image_url {
        Some(src) if src != "" ->
          image.square_img(
            src,
            160,
            "",
            "w-[80px] h-[80px] rounded-lg mr-3 shrink-0",
          )
        _ -> element.none()
      },
      html.div([attribute.class("min-w-0")], [
        html.div([attribute.class("font-semibold")], [
          element.text(text_of(marker.title)),
        ]),
        case marker.category {
          Some(kind) if kind != "" ->
            html.div([attribute.class("text-xs text-gray-400 mt-1")], [
              element.text(kind),
            ])
          _ -> element.none()
        },
        case marker.about {
          Some(text) if text != "" ->
            html.div(
              [attribute.class("text-sm text-gray-500 mt-1 line-clamp-2")],
              [element.text(text)],
            )
          _ -> element.none()
        },
      ]),
    ],
  )
}

pub fn detail(marker: Marker, lang: Lang) -> Element(msg) {
  html.div([attribute.class("page-width-sm min-h-[100svh] !pt-4 !pb-12")], [
    case marker.cover_image_url {
      Some(src) if src != "" ->
        image.exportable_img(src, "", "w-full rounded-lg mb-4")
      _ -> element.none()
    },
    html.div([attribute.class("text-2xl font-semibold")], [
      element.text(text_of(marker.title)),
    ]),
    case marker.category {
      Some(kind) if kind != "" ->
        html.div([attribute.class("text-sm text-gray-400 mt-1")], [
          element.text(kind),
        ])
      _ -> element.none()
    },
    case marker.place {
      Some(place) ->
        case place.title, place.address {
          None, None -> element.none()
          _, _ ->
            html.div([attribute.class("flex-row-item-center text-sm mt-3")], [
              html.i([attribute.class("uil-location-point mr-1")], []),
              element.text(
                text_of(place.title) <> " " <> text_of(place.address),
              ),
            ])
        }
      None -> element.none()
    },
    case marker.about {
      Some(text) if text != "" ->
        html.div([attribute.class("mt-4 whitespace-pre-line")], [
          element.text(text),
        ])
      _ -> element.none()
    },
    case marker.link {
      Some(url) if url != "" ->
        html.a(
          [
            attribute.href(url),
            attribute.attribute("target", "_blank"),
            attribute.attribute("rel", "noopener noreferrer"),
            attribute.class("text-[#6cd7b2] text-sm mt-4 inline-block"),
          ],
          [element.text(i18n.t(lang, "Open link"))],
        )
      _ -> element.none()
    },
  ])
}

fn text_of(value: Option(String)) -> String {
  case value {
    Some(text) -> text
    None -> ""
  }
}
