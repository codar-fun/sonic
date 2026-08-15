//// The event share card — `/event/share/:eventid`.
////
//// A narrow, centred card built to be screenshotted and posted: cover, title,
//// time, timezone with its offset, place, and a QR code back to the event.
//// The structure and the fixed pixel sizes are taken from seastar-app's share
//// page rather than reinvented — the result is an image people post, so the
//// exact dimensions are the design.

import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import sonic/api/types.{type Event}
import sonic/view/event_time
import sonic/view/image

/// Where a shared link points. Absolute because it goes into other people's
/// tweets and into the QR code, where a relative path means nothing.
const site = "https://sonic.sola.town"

pub fn view(event: Event) -> Element(msg) {
  html.div([attribute.class("min-h-[100svh] w-full")], [
    html.div([attribute.class("page-width min-h-[100svh] px-3 pt-0 !pb-16")], [
      html.div([attribute.class("py-6 font-semibold text-center text-xl")], [
        element.text("Share Event"),
      ]),
      html.div([attribute.class("flex flex-col items-center justify-center")], [
        card(event),
        html.div([attribute.class("my-3 w-[335px] mx-auto")], [
          social_row(event),
          action_grid(event),
        ]),
      ]),
    ]),
  ])
}

/// The card itself — the part that becomes the image. Everything outside it is
/// controls, and deliberately not part of what gets captured.
fn card(event: Event) -> Element(msg) {
  html.div(
    [
      attribute.class(
        "share-card shadow w-[335px] h-auto flex-shrink-0 bg-[#F1FCF8] p-5 pt-6 box-border overflow-hidden rounded-lg",
      ),
    ],
    [
      cover(event.cover),
      html.div(
        [
          attribute.class(
            "text-[20px] font-semibold leading-[28px] mt-[33px] mb-[22px]",
          ),
        ],
        [element.text(event.title)],
      ),
      times(event),
      timezone(event),
      place(event),
      scan_block(event),
    ],
  )
}

/// Scaled down, not cropped: the card shows the whole cover, so a wide
/// illustration stays wide instead of being centre-cut to a card thumbnail.
fn cover(url: Option(String)) -> Element(msg) {
  case url {
    Some(src) if src != "" ->
      image.exportable_img(
        src,
        "",
        "block max-h-[200px] max-w-[295px] mx-auto rounded-lg",
      )
    _ ->
      html.div(
        [
          attribute.class(
            "block h-[200px] max-w-[295px] mx-auto rounded-lg bg-gray-100",
          ),
        ],
        [],
      )
  }
}

fn times(event: Event) -> Element(msg) {
  html.div([attribute.class("flex flex-row text-xs font-normal")], [
    html.i([attribute.class("uil-calendar-alt mr-1")], []),
    html.div([attribute.class("start-time")], [
      element.text(event_time.in_zone_stamp(event.start_time, event.timezone)),
    ]),
    html.span([], [element.text("—")]),
    html.div([attribute.class("end-time")], [
      element.text(event_time.in_zone_stamp(event.end_time, event.timezone)),
    ]),
  ])
}

/// Indented to sit under the times, with no icon of its own — the line belongs
/// to the row above it.
fn timezone(event: Event) -> Element(msg) {
  case event_time.zone_line(event.start_time, event.timezone) {
    "" -> element.none()
    line ->
      html.div([attribute.class("flex flex-row text-xs font-normal")], [
        html.div([attribute.class("pl-4")], [element.text(line)]),
      ])
  }
}

/// Venue name over street address. Either half can be missing, and a card that
/// prints a bare comma or an empty line looks broken, so each is dropped on its
/// own rather than the pair being all-or-nothing.
fn place(event: Event) -> Element(msg) {
  let name = case event.place {
    Some(p) -> first_present([p.title, p.location])
    None ->
      case event.venue {
        Some(v) -> first_present([v.title, v.location])
        None -> None
      }
  }
  let address = case event.place {
    Some(p) -> first_present([p.address, p.formatted_address])
    None -> None
  }

  case name, address {
    None, None -> element.none()
    _, _ ->
      html.div(
        [attribute.class("text-xs flex flex-row items-start  mt-2")],
        [
          html.i([attribute.class("uil-location-point mr-1")], []),
          html.div([], case name, address {
            Some(n), Some(a) -> [
              element.text(n),
              html.br([]),
              element.text(a),
            ]
            Some(n), None -> [element.text(n)]
            None, Some(a) -> [element.text(a)]
            None, None -> []
          }),
        ],
      )
  }
}

/// The scan strip. Its negative margins pull it out to the card's edges,
/// undoing the card padding so the band runs full width and sits flush with
/// the bottom — the same trick upstream uses.
///
/// The QR is rendered into the HTML rather than drawn by client script: this
/// page exists to be screenshotted, and a code that only appears once a bundle
/// has run would be missing from the shot.
fn scan_block(event: Event) -> Element(msg) {
  html.div(
    [
      attribute.class(
        "bg-[rgba(149,170,163,0.15)] p-5 m-[20px_-20px_-20px] flex flex-row justify-between items-center",
      ),
    ],
    [
      html.div(
        [
          attribute.class(
            "text-[#272928] text-[14px] font-semibold leading-[19px]",
          ),
        ],
        [
          html.div([], [
            element.text("Scan the code"),
            html.br([]),
            element.text("and attend the event"),
          ]),
          html.img([
            attribute.src("/static/images/logo_horizontal.svg"),
            attribute.alt(""),
          ]),
        ],
      ),
      element.unsafe_raw_html(
        "",
        "div",
        [attribute.styles([#("width", "63px"), #("height", "63px")])],
        render_qr(event_url(event)),
      ),
    ],
  )
}

/// Share targets. Upstream renders these with react-share; the same SVGs as
/// plain links land in the same place and need no runtime, so they work on the
/// first paint.
fn social_row(event: Event) -> Element(msg) {
  let url = event_url(event)
  let text = event.title

  html.div(
    [attribute.class("flex flex-row gap-6 my-4 justify-center")],
    list.map(
      [
        #(
          "#000000",
          x_path,
          "https://twitter.com/intent/tweet?url=" <> url <> "&text=" <> text,
        ),
        #(
          "#0965FE",
          facebook_path,
          "https://www.facebook.com/sharer/sharer.php?u=" <> url,
        ),
        #(
          "#25A3E3",
          telegram_path,
          "https://t.me/share/url?url=" <> url <> "&text=" <> text,
        ),
        #(
          "#1185FE",
          bluesky_path,
          "https://bsky.app/intent/compose?text=" <> text <> " " <> url,
        ),
        #(
          "#0077B5",
          linkedin_path,
          "https://www.linkedin.com/sharing/share-offsite/?url=" <> url,
        ),
        #("#7f7f7f", email_path, "mailto:?subject=" <> text <> "&body=" <> url),
      ],
      fn(target) {
        let #(fill, path, href) = target
        html.a(
          [
            attribute.href(href),
            attribute.attribute("target", "_blank"),
            attribute.attribute("rel", "noopener noreferrer"),
            attribute.class("leading-none"),
          ],
          [social_icon(fill, path)],
        )
      },
    ),
  )
}

fn social_icon(fill: String, path: String) -> Element(msg) {
  element.unsafe_raw_html(
    "",
    "span",
    [],
    "<svg viewBox=\"0 0 64 64\" width=\"32\" height=\"32\">"
      <> "<circle cx=\"32\" cy=\"32\" r=\"32\" fill=\""
      <> fill
      <> "\"></circle>"
      <> "<path d=\""
      <> path
      <> "\" fill=\"white\"></path></svg>",
  )
}

/// Copy Link and Save Image act on the page, so they are buttons the client
/// runtime wires up; the other two are navigation and are links, which means
/// they work before any script has loaded.
fn action_grid(event: Event) -> Element(msg) {
  html.div([attribute.class("grid grid-cols-1 gap-3 w-full")], [
    html.div([attribute.class("flex-row-item-center")], [
      html.button(
        [
          attribute.id("share-copy-link"),
          attribute.attribute("data-url", event_url(event)),
          attribute.class(button_class <> " flex-1"),
        ],
        [element.text("Copy Link")],
      ),
      html.button(
        [
          attribute.id("share-save-image"),
          attribute.class(button_class <> " ml-3 flex-1"),
        ],
        [element.text("Save Image")],
      ),
    ]),
    html.div([attribute.class("flex-row-item-center")], [
      action_link("Event Detail", "/event/detail/" <> event.id, ""),
      action_link("Event Home", group_path(event, ""), " ml-3 "),
    ]),
    action_link("Create an Event", group_path(event, "/create"), ""),
  ])
}

fn action_link(label: String, href: String, extra: String) -> Element(msg) {
  html.a(
    [attribute.href(href), attribute.class(button_class <> " w-full" <> extra)],
    [element.text(label)],
  )
}

/// shadcn's secondary button, copied verbatim so these match every other
/// button on the site rather than being a lookalike that drifts.
const button_class = "font-semibold inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-lg font-semibold ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 bg-secondary text-secondary-foreground hover:brightness-95 h-11 px-4 py-2"

fn event_url(event: Event) -> String {
  site <> "/event/detail/" <> event.id
}

/// The group's own pages. An event always belongs to a group upstream, but the
/// field is optional here, so an event without one points home rather than at
/// `/event//create`.
fn group_path(event: Event, suffix: String) -> String {
  case event.group {
    Some(group) ->
      case group.name {
        Some(handle) if handle != "" -> "/event/" <> handle <> suffix
        _ -> "/"
      }
    None -> "/"
  }
}

fn first_present(values: List(Option(String))) -> Option(String) {
  case values {
    [] -> None
    [Some(value), ..] if value != "" -> Some(value)
    [_, ..rest] -> first_present(rest)
  }
}

@external(javascript, "../../../sonic_ffi.mjs", "render_qr")
fn render_qr(text: String) -> String

// Brand marks, as shipped by react-share. Kept as path data rather than as
// separate asset files so an icon cannot go missing from the image the card is
// meant to produce.
const x_path = "M 41.116 18.375 h 4.962 l -10.8405 12.39 l 12.753 16.86 H 38.005 l -7.821 -10.2255 L 21.235 47.625 H 16.27 l 11.595 -13.2525 L 15.631 18.375 H 25.87 l 7.0695 9.3465 z m -1.7415 26.28 h 2.7495 L 24.376 21.189 H 21.4255 z"

const facebook_path = "M34.1,47V33.3h4.6l0.7-5.3h-5.3v-3.4c0-1.5,0.4-2.6,2.6-2.6l2.8,0v-4.8c-0.5-0.1-2.2-0.2-4.1-0.2 c-4.1,0-6.9,2.5-6.9,7V28H24v5.3h4.6V47H34.1z"

const telegram_path = "m45.90873,15.44335c-0.6901,-0.0281 -1.37668,0.14048 -1.96142,0.41265c-0.84989,0.32661 -8.63939,3.33986 -16.5237,6.39174c-3.9685,1.53296 -7.93349,3.06593 -10.98537,4.24067c-3.05012,1.1765 -5.34694,2.05098 -5.4681,2.09312c-0.80775,0.28096 -1.89996,0.63566 -2.82712,1.72788c-0.23354,0.27218 -0.46884,0.62161 -0.58825,1.10275c-0.11941,0.48114 -0.06673,1.09222 0.16682,1.5716c0.46533,0.96052 1.25376,1.35737 2.18443,1.71383c3.09051,0.99037 6.28638,1.93508 8.93263,2.8236c0.97632,3.44171 1.91401,6.89571 2.84116,10.34268c0.30554,0.69185 0.97105,0.94823 1.65764,0.95525l-0.00351,0.03512c0,0 0.53908,0.05268 1.06412,-0.07375c0.52679,-0.12292 1.18879,-0.42846 1.79109,-0.99212c0.662,-0.62161 2.45836,-2.38812 3.47683,-3.38552l7.6736,5.66477l0.06146,0.03512c0,0 0.84989,0.59703 2.09312,0.68132c0.62161,0.04214 1.4399,-0.07726 2.14229,-0.59176c0.70766,-0.51626 1.1765,-1.34683 1.396,-2.29506c0.65673,-2.86224 5.00979,-23.57745 5.75257,-27.00686l-0.02107,0.08077c0.51977,-1.93157 0.32837,-3.70159 -0.87096,-4.74991c-0.60054,-0.52152 -1.2924,-0.7498 -1.98425,-0.77965l0,0.00176zm-0.2072,3.29069c0.04741,0.0439 0.0439,0.0439 0.00351,0.04741c-0.01229,-0.00351 0.14048,0.2072 -0.15804,1.32576l-0.01229,0.04214l-0.00878,0.03863c-0.75858,3.50668 -5.15554,24.40802 -5.74203,26.96472c-0.08077,0.34417 -0.11414,0.31959 -0.09482,0.29852c-0.1756,-0.02634 -0.50045,-0.16506 -0.52679,-0.1756l-13.13468,-9.70175c4.4988,-4.33199 9.09945,-8.25307 13.744,-12.43229c0.8218,-0.41265 0.68483,-1.68573 -0.29852,-1.70681c-1.04305,0.24584 -1.92279,0.99564 -2.8798,1.47502c-5.49971,3.2626 -11.11882,6.13186 -16.55882,9.49279c-2.792,-0.97105 -5.57873,-1.77704 -8.15298,-2.57601c2.2336,-0.89555 4.00889,-1.55579 5.75608,-2.23009c3.05188,-1.1765 7.01687,-2.7042 10.98537,-4.24067c7.94051,-3.06944 15.92667,-6.16346 16.62028,-6.43037l0.05619,-0.02283l0.05268,-0.02283c0.19316,-0.0878 0.30378,-0.09658 0.35471,-0.10009c0,0 -0.01756,-0.05795 -0.00351,-0.04566l-0.00176,0zm-20.91715,22.0638l2.16687,1.60145c-0.93418,0.91311 -1.81743,1.77353 -2.45485,2.38812l0.28798,-3.98957"

const bluesky_path = "M21.945 18.886C26.015 21.941 30.393 28.137 32 31.461 33.607 28.137 37.985 21.941 42.055 18.886 44.992 16.681 49.75 14.975 49.75 20.403 49.75 21.487 49.128 29.51 48.764 30.813 47.497 35.341 42.879 36.496 38.772 35.797 45.951 37.019 47.778 41.067 43.833 45.114 36.342 52.801 33.066 43.186 32.227 40.722 32.073 40.27 32.001 40.059 32 40.238 31.999 40.059 31.927 40.27 31.773 40.722 30.934 43.186 27.658 52.801 20.167 45.114 16.222 41.067 18.049 37.019 25.228 35.797 21.121 36.496 16.503 35.341 15.236 30.813 14.872 29.51 14.25 21.487 14.25 20.403 14.25 14.975 19.008 16.681 21.945 18.886Z"

const linkedin_path = "M20.4,44h5.4V26.6h-5.4V44z M23.1,18c-1.7,0-3.1,1.4-3.1,3.1c0,1.7,1.4,3.1,3.1,3.1 c1.7,0,3.1-1.4,3.1-3.1C26.2,19.4,24.8,18,23.1,18z M39.5,26.2c-2.6,0-4.4,1.4-5.1,2.8h-0.1v-2.4h-5.2V44h5.4v-8.6 c0-2.3,0.4-4.5,3.2-4.5c2.8,0,2.8,2.6,2.8,4.6V44H46v-9.5C46,29.8,45,26.2,39.5,26.2z"

const email_path = "M17,22v20h30V22H17z M41.1,25L32,32.1L22.9,25H41.1z M20,39V26.6l12,9.3l12-9.3V39H20z"
