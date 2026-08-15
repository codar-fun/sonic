//// Images.
////
//// Every picture on the site comes from `datastore.sola.day`, which sits
//// behind Cloudflare's image resizer. Upstream never links the original: it
//// rewrites the URL through `/cdn-cgi/image/<params>/` so the browser gets a
//// modern format at the size it will actually be drawn at, rather than a
//// full-resolution JPEG scaled down in the layout.
////
//// Sizes here mirror the ones upstream requests: 900 wide for banners,
//// 454×296 for cards, 28×28 for avatars.

import gleam/int
import gleam/list
import gleam/option
import gleam/string
import lustre/attribute.{type Attribute, attribute}
import lustre/element.{type Element}
import lustre/element/html

const host = "https://datastore.sola.day/"

/// A banner: wide, scaled down rather than cropped, so nothing is cut off.
pub fn banner(url: String) -> String {
  transform(url, "format=auto,quality=85,width=900,fit=scale-down")
}

/// A card cover: cropped to a fixed box, because the grid needs one shape.
pub fn card(url: String) -> String {
  transform(url, "format=auto,quality=85,width=454,height=296,fit=cover")
}

/// An avatar. Small enough that the transform saves more than it costs.
pub fn avatar(url: String) -> String {
  transform(url, "format=auto,quality=85,width=28,height=28,fit=cover")
}

/// Route a datastore URL back through this server.
///
/// Only the share card uses this. The CDN answers without CORS headers, so a
/// canvas that has drawn one of its images cannot be exported — and exporting
/// the card is what "Save Image" does. Same-origin bytes cost an extra hop, so
/// this is not the default anywhere else.
pub fn proxied(url: String) -> String {
  case string.starts_with(url, host) {
    False -> url
    True -> "/proxy/image/" <> string.drop_start(url, string.length(host))
  }
}

/// Rewrite a datastore URL through the resizer.
///
/// Anything else is returned untouched: the transform only exists on that
/// host, and prefixing a foreign URL with it would produce a 404 where there
/// was a working image.
fn transform(url: String, params: String) -> String {
  case string.starts_with(url, host) {
    False -> url
    True ->
      case string.starts_with(url, host <> "cdn-cgi/") {
        // Already transformed — don't nest one inside another.
        True -> url
        False ->
          host
          <> "cdn-cgi/image/"
          <> params
          <> "/"
          <> string.drop_start(url, string.length(host))
      }
  }
}

/// Attributes every image should carry.
///
/// `loading=lazy` on anything below the fold and `decoding=async` everywhere:
/// neither blocks first paint, and the banner opts out because it *is* the
/// first paint.
pub fn lazy() -> List(Attribute(msg)) {
  [attribute("loading", "lazy"), attribute("decoding", "async")]
}

pub fn eager() -> List(Attribute(msg)) {
  [
    attribute("fetchpriority", "high"),
    attribute("loading", "eager"),
    attribute("decoding", "async"),
  ]
}

/// A lazily-loaded image with the resizer applied at card size.
pub fn card_img(src: String, alt: String, classes: String) -> Element(msg) {
  html.img([
    attribute.src(card(src)),
    attribute.alt(alt),
    attribute.class(classes),
    ..lazy()
  ])
}

/// An eagerly-loaded banner image, routed through this server's proxy.
///
/// For images that must survive a canvas export — currently only the share
/// card's cover. Eager because such an image is the subject of its page, and
/// the proxy because the CDN sends no CORS headers. Everywhere else, link the
/// CDN directly and skip both costs.
pub fn exportable_img(src: String, alt: String, classes: String) -> Element(msg) {
  html.img([
    attribute.src(proxied(banner(src))),
    // Declared so the canvas export does not have to guess at the origin.
    attribute("crossorigin", "anonymous"),
    attribute.alt(alt),
    attribute.class(classes),
    ..eager()
  ])
}

/// A lazily-loaded avatar.
pub fn avatar_img(src: String, classes: String) -> Element(msg) {
  html.img([
    attribute.src(avatar(src)),
    attribute.alt(""),
    attribute.class(classes),
    ..lazy()
  ])
}

/// A deterministic default avatar for anything without a picture.
///
/// The same id always maps to the same face, so a card does not change
/// appearance between page loads. Six shipped images, matching upstream.
pub fn default_avatar(id: String) -> String {
  let sum =
    id
    |> string.to_utf_codepoints
    |> list.fold(0, fn(acc, point) { acc + string.utf_codepoint_to_int(point) })
  "/static/images/default_avatar/avatar_" <> int.to_string(sum % 6) <> ".png"
}

/// An avatar that always renders something: the resized picture when there is
/// one, a stable default otherwise. Grey circles were appearing wherever a
/// profile had no image.
pub fn avatar_or_default(
  url: option.Option(String),
  id: String,
  classes: String,
) -> Element(msg) {
  let src = case url {
    option.Some(value) if value != "" -> avatar(value)
    _ -> default_avatar(id)
  }
  html.img([
    attribute.src(src),
    attribute.alt(""),
    attribute.class(classes <> " object-cover shrink-0"),
    ..lazy()
  ])
}
