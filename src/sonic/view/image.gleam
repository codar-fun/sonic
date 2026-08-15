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

/// A lazily-loaded avatar.
pub fn avatar_img(src: String, classes: String) -> Element(msg) {
  html.img([
    attribute.src(avatar(src)),
    attribute.alt(""),
    attribute.class(classes),
    ..lazy()
  ])
}
