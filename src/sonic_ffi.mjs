// The only JavaScript in the project: the host's `fetch`, plus the Node HTTP
// server used for SSR. Everything else is Gleam.
//
// Errors are returned as values (Ok/Error tuples) rather than thrown, so the
// Gleam side can pattern-match on failure instead of relying on exceptions.

import { createServer } from "node:http";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { Ok, Error as GleamError, List } from "./gleam.mjs";

// Gleam represents #(a, b) as a JS array subclass; a plain array is the
// representation the compiler accepts back.
function tuple2(a, b) {
  return [a, b];
}

function toHeaderObject(headers) {
  const out = {};
  for (const pair of headers) {
    // gleam lists iterate as arrays of #(key, value)
    const [key, value] = pair;
    out[key] = value;
  }
  return out;
}

export function argv() {
  return List.fromArray(process.argv.slice(2));
}

export function host() {
  return process.env.SONIC_HOST ?? "127.0.0.1";
}

// One HTTP server. The handler is Gleam: it takes a path and returns a promise
// of #(status, html). Everything about routing and rendering lives there.
//
// The bind address is deliberately configurable and defaults to loopback.
// Inside a container it MUST be 0.0.0.0 (set SONIC_HOST): Traefik on this host
// is a docker provider and connects to the container's network address, so a
// container-internal loopback bind yields a healthy container, a live router,
// and a uniform 502. Not exposing a port on the *host* is a separate concern
// from what the process listens on *inside* the container.
// Static assets are served here rather than in Gleam: reading bytes off disk
// and setting cache headers is a platform concern, and routing it through the
// Gleam handler would mean carrying binary payloads through a String type.
// Resolved from the working directory, not from import.meta.url: the compiled
// module lives under build/dev/javascript/sonic/, so a path relative to itself
// would point inside the build tree. Both `gleam run` from the project root and
// the container (WORKDIR /app) put priv/ where this expects it.
const STATIC_ROOT = pathToFileURL(join(process.cwd(), "priv", "static") + "/");
// Compiled Gleam modules, served as native ESM under /static/js/. No bundler:
// the compiler already emits modules, and adding one would be a build step
// earning nothing at this size.
const JS_ROOT = pathToFileURL(
  join(process.cwd(), process.env.SONIC_JS_ROOT ?? "build/dev/javascript") + "/",
);
const CONTENT_TYPES = {
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".woff2": "font/woff2",
  ".woff": "font/woff",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".ico": "image/x-icon",
};

function serveStatic(req, res) {
  const url = (req.url ?? "").split("?")[0];
  if (url.startsWith("/static/js/")) {
    return serveFrom(JS_ROOT, url.slice("/static/js/".length), res);
  }
  const name = url.slice("/static/".length);
  // Reject anything that could climb out of the asset directory.
  return serveFrom(STATIC_ROOT, name, res);
}

function serveFrom(root, name, res) {
  // Reject anything that could climb out of the served directory.
  if (!name || name.includes("..") || name.startsWith("/")) return false;

  const file = new URL(name, root);
  if (!file.pathname.startsWith(root.pathname)) return false;

  let body;
  try {
    body = readFileSync(file);
  } catch {
    return false;
  }

  const ext = name.slice(name.lastIndexOf("."));
  res.writeHead(200, {
    "content-type": CONTENT_TYPES[ext] ?? "application/octet-stream",
    // Assets are content-addressed by the deploy (a new image means new
    // bytes), so they can be cached hard.
    "cache-control": "public, max-age=31536000, immutable",
  });
  res.end(body);
  return true;
}

// The image CDN answers without CORS headers, so a canvas that has drawn one
// of its images is tainted and cannot be exported. The share card's "Save
// Image" needs exactly that, so its cover is fetched through here instead,
// making it same-origin.
//
// Only this one host, and only its resizer path: an open proxy would let a
// caller aim this server at anything it can reach, including addresses only
// reachable from inside the network.
const IMAGE_PROXY_PREFIX = "/proxy/image/";
const IMAGE_PROXY_ORIGIN = "https://datastore.sola.day";

async function proxyImage(req, res) {
  const path = (req.url ?? "").slice(IMAGE_PROXY_PREFIX.length);
  if (!path || path.includes("..") || path.startsWith("/")) {
    res.writeHead(400).end("bad path");
    return;
  }
  try {
    const upstream = await fetch(`${IMAGE_PROXY_ORIGIN}/${path}`);
    if (!upstream.ok) {
      res.writeHead(upstream.status).end("");
      return;
    }
    const body = Buffer.from(await upstream.arrayBuffer());
    res.writeHead(200, {
      "content-type": upstream.headers.get("content-type") ?? "image/jpeg",
      "cache-control": "public, max-age=86400",
      // The point of the proxy: same-origin bytes the canvas can export.
      "access-control-allow-origin": "*",
    });
    res.end(body);
  } catch {
    res.writeHead(502).end("upstream unavailable");
  }
}

export function serve(port, handler) {
  const bind = host();
  const server = createServer(async (req, res) => {
    try {
      if ((req.url ?? "").startsWith("/static/") && serveStatic(req, res)) {
        return;
      }
      if ((req.url ?? "").startsWith(IMAGE_PROXY_PREFIX)) {
        await proxyImage(req, res);
        return;
      }
      const body = await readBody(req);
      const [status, html, location, setCookie] = await handler(
        req.method ?? "GET",
        req.url ?? "/",
        body,
        req.headers.cookie ?? "",
      );

      const headers = {
        "content-type": "text/html; charset=utf-8",
        // Pages reflect the caller's session, so they must never be cached by
        // a shared proxy and handed to someone else.
        "cache-control": "no-store",
      };
      if (location) headers["location"] = location;
      if (setCookie) headers["set-cookie"] = setCookie;

      res.writeHead(status, headers);
      res.end(html);
    } catch (err) {
      // A throw here means a bug in the handler rather than a bad request;
      // say so plainly instead of hanging the socket.
      res.writeHead(500, { "content-type": "text/plain; charset=utf-8" });
      res.end(`handler crashed: ${err?.stack ?? err}`);
    }
  });
  server.listen(port, bind);
  return undefined;
}

// Bounded so a large or slow body cannot hold a connection open indefinitely.
const MAX_BODY_BYTES = 64 * 1024;

function readBody(req) {
  if (req.method !== "POST" && req.method !== "PUT" && req.method !== "PATCH") {
    return Promise.resolve("");
  }
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on("data", (chunk) => {
      size += chunk.length;
      if (size > MAX_BODY_BYTES) {
        req.destroy();
        resolve("");
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    req.on("error", reject);
  });
}

export async function fetch_text(method, url, headers, body) {
  try {
    const init = {
      method,
      headers: toHeaderObject(Array.from(headers)),
    };
    if (method !== "GET" && method !== "HEAD" && body !== "") {
      init.body = body;
    }
    const res = await fetch(url, init);
    const text = await res.text();
    return new Ok(tuple2(res.status, text));
  } catch (err) {
    return new GleamError(String(err?.message ?? err));
  }
}


// Format a UTC timestamp in a named zone.
//
// The API sends UTC and names the event's zone separately; showing the UTC
// clock time with the zone label appended states the wrong time — 07:30
// labelled Asia/Bangkok when the event starts at 14:30 there. Intl carries the
// tz database, so this is one of the "necessary parts" that belongs in JS.
export function format_in_zone(iso, zone, pattern) {
  try {
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return "";
    // "2024-12-06 14:30" — the share card's format. Composed from parts rather
    // than from a locale, because a locale that happens to print ISO-ish dates
    // today is not a promise that it will tomorrow.
    if (pattern === "stamp") {
      const parts = new Intl.DateTimeFormat("en-US", {
        timeZone: zone,
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
        hour: "2-digit",
        minute: "2-digit",
        hour12: false,
      }).formatToParts(d);
      const at = (type) => parts.find((p) => p.type === type)?.value ?? "";
      // hourCycle h23 still prints "24" for midnight in some ICU versions.
      const hour = at("hour") === "24" ? "00" : at("hour");
      return `${at("year")}-${at("month")}-${at("day")} ${hour}:${at("minute")}`;
    }
    const opts =
      pattern === "date"
        ? { weekday: "short", year: "numeric", month: "short", day: "2-digit" }
        : { hour: "2-digit", minute: "2-digit", hour12: false };
    return new Intl.DateTimeFormat("en-US", { ...opts, timeZone: zone }).format(d);
  } catch {
    return "";
  }
}

// The zone's UTC offset at that instant, e.g. "GMT+7".
export function zone_label(iso, zone) {
  try {
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return "";
    const parts = new Intl.DateTimeFormat("en-US", {
      timeZone: zone,
      timeZoneName: "shortOffset",
    }).formatToParts(d);
    return parts.find((p) => p.type === "timeZoneName")?.value ?? "";
  } catch {
    return "";
  }
}

// The schedule's date window.
//
// Upstream's getInterval: the list and week views cover the current week, the
// compact and venue views a single day. Without a window the schedule asked
// for events by page count and got the group's whole history under a heading
// that says this week.
//
// Computed in the group's timezone, not the server's: "today" in Bangkok is a
// different day from "today" in UTC for seven hours out of every twenty-four,
// and a schedule that starts on the wrong day is wrong for everyone reading it
// from the place the events happen.
export function schedule_interval(zone, view, startDate) {
  const tz = zone || "UTC";
  // An explicit start_date anchors the window; otherwise it is anchored to
  // today in the group's zone. This is what makes the arrows plain links —
  // moving a week is a different URL, not client state.
  const today = startDate ? parseDate(startDate) ?? zonedToday(tz) : zonedToday(tz);
  if (view === "week" || view === "list") {
    // Monday, not Sunday: upstream sets `weekStart: 1` on its dayjs locale, so
    // a Sunday start shifted every heading by a day.
    const day = today.getUTCDay();
    const start = addDays(today, day === 0 ? -6 : 1 - day);
    return [isoDate(start), isoDate(addDays(start, 6))];
  }
  return [isoDate(today), isoDate(today)];
}

// Every date in the schedule's window, as YYYY-MM-DD.
//
// The week grid needs all seven columns whether or not anything is scheduled
// on a given day, so it cannot derive them from the events it received — a
// quiet Tuesday would simply vanish and shift the rest of the week left.
export function schedule_days(zone, view, startDate) {
  const [from, to] = schedule_interval(zone, view, startDate);
  const days = [];
  let current = new Date(`${from}T00:00:00Z`);
  const last = new Date(`${to}T00:00:00Z`);
  while (current <= last) {
    days.push(isoDate(current));
    current = addDays(current, 1);
  }
  return List.fromArray(days);
}

// A YYYY-MM-DD string as a UTC-midnight Date, or null if it is not one.
function parseDate(text) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(text)) return null;
  const d = new Date(`${text}T00:00:00Z`);
  return Number.isNaN(d.getTime()) ? null : d;
}

// The window shifted one step earlier or later: a week for the week and list
// views, a day for compact and venue. Returned as the date to anchor the next
// URL to, so the arrows are links.
export function schedule_step(zone, view, startDate, direction) {
  const [from] = schedule_interval(zone, view, startDate);
  const span = view === "week" || view === "list" ? 7 : 1;
  return isoDate(addDays(new Date(`${from}T00:00:00Z`), span * direction));
}

// Today's calendar date in a zone, as YYYY-MM-DD. The schedule marks it.
export function today_in_zone(zone) {
  return isoDate(zonedToday(zone || "UTC"));
}

// "Mon 10" — a week-grid column header.
export function weekday_label(date) {
  try {
    const d = new Date(`${date}T00:00:00Z`);
    if (Number.isNaN(d.getTime())) return date;
    const weekday = new Intl.DateTimeFormat("en-US", {
      weekday: "short",
      timeZone: "UTC",
    }).format(d);
    return `${weekday} ${d.getUTCDate()}`;
  } catch {
    return date;
  }
}

// "2026 August" — the schedule's month label.
export function month_label(zone, startDate) {
  const tz = zone || "UTC";
  const today = startDate ? parseDate(startDate) ?? zonedToday(tz) : zonedToday(tz);
  const month = new Intl.DateTimeFormat("en-US", {
    month: "long",
    timeZone: "UTC",
  }).format(today);
  return `${today.getUTCFullYear()} ${month}`;
}

// Today's calendar date in `zone`, carried as a UTC-midnight Date so the
// arithmetic above cannot be moved across a boundary by a local offset.
function zonedToday(zone) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: zone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
  return new Date(`${parts}T00:00:00Z`);
}

function addDays(date, days) {
  return new Date(date.getTime() + days * 86400000);
}

function isoDate(date) {
  return date.toISOString().slice(0, 10);
}

// Markdown, rendered with the same library upstream uses so event bodies read
// the same way. `html: false` means raw HTML in the source is escaped rather
// than passed through — event descriptions are user-supplied, and this is the
// difference between a formatted paragraph and a script tag on the page.
import MarkdownIt from "markdown-it";

const md = new MarkdownIt({
  html: false,
  linkify: true,
  breaks: true,
});

export function render_markdown(source) {
  try {
    return md.render(source);
  } catch {
    return "";
  }
}

// QR codes for the share card. Built synchronously from the low-level API:
// QRCode.toString returns a promise, and awaiting it here would mean threading
// async through every view function for one image. Rendered server-side so the
// card is complete in the HTML — this page exists to be screenshotted, and a
// code that appears only after client JS ran would be missing from the shot.
import QRCode from "qrcode";

export function render_qr(text) {
  try {
    const qr = QRCode.create(text, { errorCorrectionLevel: "M" });
    const n = qr.modules.size;
    const data = qr.modules.data;
    let path = "";
    for (let y = 0; y < n; y++) {
      for (let x = 0; x < n; x++) {
        if (data[y * n + x]) path += `M${x} ${y}h1v1h-1z`;
      }
    }
    return (
      // Sized by its container rather than by fixed attributes: the card gives
      // it a 63px box, and a 120px SVG inside that overflowed to the right —
      // visible on the page and clipped out of the exported image.
      `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${n} ${n}" ` +
      `width="100%" height="100%" shape-rendering="crispEdges">` +
      `<rect width="${n}" height="${n}" fill="#fff"/>` +
      `<path d="${path}" fill="#000"/></svg>`
    );
  } catch {
    return "";
  }
}
