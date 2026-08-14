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

// One HTTP server. The handler is Gleam: it takes a path and returns a promise
// of #(status, html). Everything about routing and rendering lives there.
export function serve(port, handler) {
  const server = createServer(async (req, res) => {
    try {
      const [status, html] = await handler(req.url ?? "/");
      res.writeHead(status, {
        "content-type": "text/html; charset=utf-8",
        "cache-control": "no-store",
      });
      res.end(html);
    } catch (err) {
      // A throw here means a bug in the handler rather than a bad request;
      // say so plainly instead of hanging the socket.
      res.writeHead(500, { "content-type": "text/plain; charset=utf-8" });
      res.end(`handler crashed: ${err?.stack ?? err}`);
    }
  });
  server.listen(port, "127.0.0.1");
  return undefined;
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
