// The only JavaScript in the project: the host's `fetch`, plus the Node HTTP
// server used for SSR. Everything else is Gleam.
//
// Errors are returned as values (Ok/Error tuples) rather than thrown, so the
// Gleam side can pattern-match on failure instead of relying on exceptions.

import { createServer } from "node:http";
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
export function serve(port, handler) {
  const bind = host();
  const server = createServer(async (req, res) => {
    try {
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
