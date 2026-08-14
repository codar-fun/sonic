//// The document shell every page is wrapped in.
////
//// Styles are inlined rather than pulled from a CDN so a rendered page is
//// self-contained and testable offline — the SSR output can be asserted on
//// without a network round trip for assets.

import lustre/attribute.{attribute}
import lustre/element.{type Element}
import lustre/element/html

pub fn document(body: Element(msg)) -> Element(msg) {
  html.html([attribute("lang", "en")], [
    html.head([], [
      html.meta([attribute("charset", "utf-8")]),
      html.meta([
        attribute("name", "viewport"),
        attribute("content", "width=device-width, initial-scale=1"),
      ]),
      html.title([], "sonic"),
      html.style([], css),
    ]),
    html.body([], [header(), html.main([attribute.class("wrap")], [body])]),
  ])
}

fn header() -> Element(msg) {
  html.header([attribute.class("bar")], [
    html.a([attribute.href("/"), attribute.class("brand")], [
      element.text("sonic"),
    ]),
  ])
}

const css = "
:root { color-scheme: light dark; --fg: #14161a; --muted: #6b7280; --line: #e5e7eb; --bg: #ffffff; --accent: #2563eb; }
@media (prefers-color-scheme: dark) {
  :root { --fg: #e8eaed; --muted: #9aa0a6; --line: #2a2d31; --bg: #14161a; --accent: #7aa2f7; }
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--fg);
  font: 16px/1.5 ui-sans-serif, system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif; }
.bar { border-bottom: 1px solid var(--line); padding: 14px 20px; }
.brand { font-weight: 650; letter-spacing: -0.01em; text-decoration: none; color: var(--fg); }
.wrap { max-width: 860px; margin: 0 auto; padding: 28px 20px 64px; }
h1 { font-size: 1.6rem; line-height: 1.25; margin: 0 0 6px; letter-spacing: -0.02em; }
h2 { font-size: 1.05rem; margin: 28px 0 10px; }
a { color: var(--accent); }
.muted { color: var(--muted); }
.meta { color: var(--muted); font-size: 0.9rem; }
.list { list-style: none; margin: 0; padding: 0; display: grid; gap: 14px; }
.card { border: 1px solid var(--line); border-radius: 12px; padding: 14px 16px; }
.card h3 { margin: 0 0 4px; font-size: 1rem; }
.card a { text-decoration: none; color: inherit; }
.card a:hover h3 { color: var(--accent); }
.cover { width: 100%; max-height: 320px; object-fit: cover; border-radius: 12px; margin-bottom: 18px; }
.tags { display: flex; flex-wrap: wrap; gap: 6px; margin: 10px 0 0; padding: 0; list-style: none; }
.tag { font-size: 0.78rem; border: 1px solid var(--line); border-radius: 999px; padding: 2px 9px; color: var(--muted); }
.notes { white-space: pre-wrap; margin-top: 8px; }
.empty { color: var(--muted); padding: 40px 0; text-align: center; }
.err code { font-size: 0.85rem; word-break: break-all; }
"
