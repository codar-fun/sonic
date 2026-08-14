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

export function serve(port, handler) {
  const bind = host();
  const server = createServer(async (req, res) => {
    try {
      if ((req.url ?? "").startsWith("/static/") && serveStatic(req, res)) {
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

