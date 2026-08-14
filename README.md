# sonic

A Gleam + [Lustre](https://github.com/lustre-labs/lustre) rewrite of
[`seastar-app`](https://github.com/sociallayer-im/seastar-app), talking to the
hosted soon API at `https://api.sola.day`.

**Status: vertical slice.** Two routes render server-side against the live API.
This is not yet a replacement for seastar-app — see *Scope* below for the
distance between here and that.

## Running it

```sh
export PATH="$HOME/.local/bin:$HOME/.local/node/bin:$PATH"

gleam run              # SSR server on http://127.0.0.1:3000
gleam run -- --smoke   # one live API call, prints what came back
gleam test             # decoders, against a captured real payload
```

No Erlang is required. The project targets JavaScript and runs on the Node 22
already present on this host, which keeps the toolchain off the system package
manager entirely — this machine runs other services, so adding a third-party
apt source to install an Erlang/OTP was not worth it.

## Layout

| Path | What lives there |
|---|---|
| `src/sonic/api/types.gleam` | Domain types and `ApiError` |
| `src/sonic/api/decoders.gleam` | JSON → types |
| `src/sonic/api/client.gleam` | The one transport (`get` / `post`) |
| `src/sonic/api/event.gleam` | Event endpoints, one function per call |
| `src/sonic/router.gleam` | `Route` type, parser, and href printer |
| `src/sonic/view/` | Lustre views, shared by server and browser |
| `src/sonic/server.gleam` | Routing → fetch → `element.to_string` |
| `src/sonic_ffi.mjs` | The only JavaScript: `fetch`, `http.createServer`, `argv` |

The rule the layout encodes: **one transport, one router, one set of views.**
Views are ordinary functions returning `Element(msg)`, so the same definition
serves SSR today and client-side rendering when hydration lands.

## What has actually been verified

Checked by running it, not by reading docs:

- Gleam 1.18.1 compiles and runs on the JS target with no Erlang present.
- `gleam run -- --smoke` fetches and decodes live events from `api.sola.day`.
- SSR emits a complete document with real event data in the markup —
  `GET /` returned 200 with event titles present in the HTML, not fetched later
  by script.
- `GET /event/detail/<real id>` returned 200 with title, formatted time range,
  host and attendance rendered server-side.
- Unknown path → 404; unknown event id → upstream 404 mapped to a 404 page.
- 9 decoder tests pass against a payload captured from the live API.

## What has not

- **No client-side hydration yet.** Views are SSR-only yet written so a Lustre
  app can mount them unchanged; that claim is untested until it is done.
- **No authentication.** Every call runs unauthenticated, so only public data
  is reachable. Endpoints needing a token return `HttpError(401, _)` rather
  than an empty list, deliberately: "not signed in" must not look like
  "nothing to show".
- **No write paths**, no forms, no payments, no uploads.

## Scope

`seastar-app` is 88 route pages, ~41,700 lines of TypeScript, plus a
173-function SDK across 14 domains (auth, event, group, badge, venue, track,
ticket, promo code, checkin, map, calendar, dashboard, embeds, Stripe, WeChat).
Rewriting it with functional parity is a large programme of work, not a single
delivery. This slice exists to answer the questions that decide whether the
programme is viable at all — SSR, the transport, and schema fidelity — before
volume work begins.

## Decisions worth knowing

**Decoders follow the wire, not the TypeScript.** Several fields that
`seastar-app`'s declarations type as non-optional (`category`, `timezone`,
`place`, `venue`, `track`) arrive `null` on real rows. Where the two disagree
the wire wins, because the wire is what actually shows up.

**Optional means null-or-absent; wrong type still fails.** Tolerating both
missing and null keys keeps the client robust to harmless schema additions,
while a type mismatch still errors — tolerance should not slide into blindness.

**API errors are values, not exceptions.** `ApiError` distinguishes "the server
said no" (`HttpError`), "we could not read the reply" (`DecodeError`) and "the
request never completed" (`NetworkError`). Rendering can then choose a status
and a message per case instead of collapsing everything into a 500.
