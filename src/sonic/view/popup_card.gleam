//// The pop-up city card.
////
//// Shared by the home page and /popup-city so the two cannot drift — they
//// showed the same card before, in two copies.

import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{type PopupCity}
import sonic/view/event_time
import sonic/view/image

pub fn view(city: PopupCity) -> Element(msg) {
  html.a(
    [
      attribute.href("/event/" <> handle(city)),
      attribute.class(
        "rounded shadow p-3 duration-200 hover:translate-y-[-6px]",
      ),
    ],
    [
      html.div([attribute.class("rounded aspect-[3/2] mb-3 overflow-hidden")], [
        cover(first_present([city.image_url, city.banner_image_url])),
      ]),
      // Dates first, then the name: upstream leads with when, not what.
      html.div([attribute.class("webkit-box-clamp-1 sm:text-sm text-xs")], [
        element.text(option_text(dates(city))),
      ]),
      html.div(
        [
          attribute.class(
            "webkit-box-clamp-2 text-lg font-semibold leading-5 h-10 mb-4",
          ),
        ],
        [element.text(display_name(city.nickname, city.name, city.id))],
      ),
      html.div([attribute.class("flex items-end flex-row justify-between")], [
        html.div([attribute.class("flex-1")], [
          case city.location {
            Some(place) if place != "" ->
              html.div([attribute.class("flex-row-item-center text-xs")], [
                html.i([attribute.class("uil-location-point mr-0.5")], []),
                html.div([attribute.class("webkit-box-clamp-1 break-all")], [
                  element.text(place),
                ]),
              ])
            _ -> element.none()
          },
          html.div([attribute.class("flex-row-item-center text-xs")], [
            image.avatar_or_default(
              city.image_url,
              city.id,
              28,
              "w-[14px] h-[14px] rounded-full mr-0.5",
            ),
            html.div([attribute.class("webkit-box-clamp-1")], [
              element.text(
                "by " <> display_name(city.nickname, city.name, city.id),
              ),
            ]),
          ]),
        ]),
      ]),
    ],
  )
}

fn cover(url: Option(String)) -> Element(msg) {
  case url {
    Some(src) if src != "" ->
      image.card_img(src, "", "object-cover w-full h-full rounded")
    _ -> html.div([attribute.class("w-full h-full bg-gray-100 rounded")], [])
  }
}

fn dates(city: PopupCity) -> Option(String) {
  case city.start_date, city.end_date {
    Some(start), Some(end) -> Some(event_time.date_span(start, end))
    Some(start), None -> Some(event_time.one_date(start))
    _, _ -> None
  }
}

fn handle(city: PopupCity) -> String {
  case city.name {
    Some(name) if name != "" -> name
    _ -> city.id
  }
}

fn display_name(
  nickname: Option(String),
  name: Option(String),
  fallback: String,
) -> String {
  case nickname, name {
    Some(value), _ if value != "" -> value
    _, Some(value) if value != "" -> value
    _, _ -> fallback
  }
}

fn first_present(values: List(Option(String))) -> Option(String) {
  case values {
    [Some(value), ..] if value != "" -> Some(value)
    [_, ..rest] -> first_present(rest)
    [] -> None
  }
}

fn option_text(value: Option(String)) -> String {
  case value {
    Some(text) -> text
    None -> ""
  }
}
