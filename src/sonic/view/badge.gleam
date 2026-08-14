//// The shadcn Badge, as seastar-app uses it.
////
//// Base and variant classes are copied from `components/shadcn/Badge.tsx`.
//// The status variants resolve through CSS custom properties that already
//// exist in the copied globals.css, so they pick up the original's palette
//// rather than an approximation of it.

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub type Variant {
  Hosting
  Past
  Private
  Pending
  Cancel
  Ongoing
  Upcoming
}

const base = "inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2"

pub fn view(variant: Variant, label: String) -> Element(msg) {
  html.div([attribute.class(base <> " " <> classes(variant) <> " mr-1")], [
    element.text(label),
  ])
}

fn classes(variant: Variant) -> String {
  case variant {
    Hosting -> "border-transparent bg-[#e7f4ff] text-[#5992ff]"
    Pending -> "border-transparent bg-[#fff7e8] text-[#e7c54e]"
    Cancel -> "border-transparent bg-[#bdbdbd] text-[#fff]"
    Private -> "border-transparent bg-[#f8f2ff] text-[#c863ff]"
    Ongoing ->
      "border-transparent bg-[var(--ongoing-background)] text-[var(--ongoing-foreground)]"
    Past ->
      "border-transparent bg-[var(--past-background)] text-[var(--past-foreground)]"
    Upcoming ->
      "border-transparent bg-[var(--upcoming-background)] text-[var(--upcoming-foreground)]"
  }
}
