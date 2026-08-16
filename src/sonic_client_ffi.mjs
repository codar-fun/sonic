// Browser-only FFI.
//
// Kept apart from sonic_ffi.mjs because that one imports node:http and node:fs.
// A browser loading it fails on those imports, so the split is not tidiness —
// it is what makes the client bundle loadable at all.

export function signed_in_flag() {
  const root = globalThis.document?.querySelector("#account-menu");
  return root?.dataset?.signedIn === "true";
}

// The language the server rendered in. The menu is re-rendered on the client,
// and without this it came back in English on a Chinese page.
export function current_lang() {
  const root = globalThis.document?.querySelector("#account-menu");
  return root?.dataset?.lang ?? "en";
}

// The share card's two buttons that act on the page rather than navigate.
//
// Wired here with plain listeners instead of as a Lustre app: neither one has
// state worth a model, and mounting a runtime over the card would mean the
// thing being screenshotted is re-rendered by script — the opposite of what
// this page wants.
export function wire_share_buttons() {
  const doc = globalThis.document;
  if (!doc) return undefined;

  const copy = doc.querySelector("#share-copy-link");
  if (copy) {
    copy.addEventListener("click", async () => {
      const url = copy.dataset.url ?? globalThis.location.href;
      try {
        await navigator.clipboard.writeText(url);
        flash(copy, "Copied");
      } catch {
        // Clipboard access is refused on insecure origins and by some
        // browsers without a user gesture they recognise. Say so rather than
        // appearing to succeed.
        flash(copy, "Press ⌘C");
        selectText(url);
      }
    });
  }

  const save = doc.querySelector("#share-save-image");
  if (save) {
    save.addEventListener("click", async () => {
      const card = doc.querySelector(".share-card");
      if (!card) return;
      const original = save.textContent;
      save.textContent = "Saving…";
      try {
        // Imported on click, not at load: it is ~60KB that only matters to
        // whoever presses this button.
        const { toPng, getFontEmbedCSS } = await import(
          "/static/vendor/html-to-image/index.js"
        );
        // Wait for the icon font: the clone inherits font-family, so capturing
        // before the face has loaded bakes tofu boxes into the image where the
        // calendar and location glyphs belong.
        if (doc.fonts?.ready) await doc.fonts.ready;
        // Measured, not assumed. The scan strip uses negative margins to reach
        // the card's edges, and without an explicit box the capture came out
        // narrower than the card and clipped the QR code off the right side.
        const box = card.getBoundingClientRect();
        // html-to-image decides which @font-face rules to inline by walking
        // *elements* and reading their computed font-family. The icon font is
        // applied to ::before, which that walk never visits, so the calendar
        // and location glyphs came out of the export as tofu boxes. The icon
        // faces are collected separately and appended.
        const fontEmbedCSS =
          (await getFontEmbedCSS(card)) + "\n" + (await pseudoFontCSS(card));
        const url = await toPng(card, {
          fontEmbedCSS,
          // The card's own background, so the export is not transparent where
          // the page colour used to be.
          backgroundColor: "#F1FCF8",
          pixelRatio: 2,
          width: Math.ceil(box.width),
          height: Math.ceil(box.height),
        });
        const link = doc.createElement("a");
        link.download = "event.png";
        link.href = url;
        link.click();
        save.textContent = original;
      } catch {
        flash(save, "Save failed");
      }
    });
  }
  return undefined;
}

// @font-face rules for fonts used only by ::before / ::after inside `node`.
//
// The icon font ships as 21 unicode-range shards. Embedding all of them would
// put ~450KB of base64 into one export, so only the shards whose range covers
// a glyph actually on the card are inlined — usually one or two.
async function pseudoFontCSS(node) {
  const families = new Set();
  const codepoints = new Set();

  for (const el of [node, ...node.querySelectorAll("*")]) {
    for (const pseudo of ["::before", "::after"]) {
      const style = getComputedStyle(el, pseudo);
      const content = style.content;
      if (!content || content === "none" || content === "normal") continue;
      // Computed content comes back quoted: "\"\"".
      const text = content.replace(/^["']|["']$/g, "");
      for (const ch of text) codepoints.add(ch.codePointAt(0));
      for (const family of style.fontFamily.split(",")) {
        families.add(family.trim().replace(/^["']|["']$/g, "").toLowerCase());
      }
    }
  }
  if (!codepoints.size) return "";

  const rules = [];
  for (const sheet of document.styleSheets) {
    let sheetRules;
    try {
      sheetRules = sheet.cssRules;
    } catch {
      // A cross-origin stylesheet cannot be read. Skipping it is correct:
      // its faces are not ours to inline.
      continue;
    }
    for (const rule of sheetRules) {
      if (rule.type !== CSSRule.FONT_FACE_RULE) continue;
      const family = rule.style.fontFamily
        ?.trim()
        .replace(/^["']|["']$/g, "")
        .toLowerCase();
      if (!families.has(family)) continue;
      const range = rule.style.getPropertyValue("unicode-range");
      if (range && !rangeCovers(range, codepoints)) continue;
      rules.push(rule);
    }
  }

  const texts = await Promise.all(rules.map(inlineFontRule));
  return texts.filter(Boolean).join("\n");
}

// Does a `unicode-range` value cover any of these codepoints? Handles the
// single, range and wildcard forms (U+e900, U+e900-e9ff, U+e9??).
function rangeCovers(value, codepoints) {
  for (const part of value.split(",")) {
    const spec = part.trim().replace(/^u\+/i, "");
    let from;
    let to;
    if (spec.includes("-")) {
      const [a, b] = spec.split("-");
      from = parseInt(a, 16);
      to = parseInt(b, 16);
    } else if (spec.includes("?")) {
      from = parseInt(spec.replace(/\?/g, "0"), 16);
      to = parseInt(spec.replace(/\?/g, "f"), 16);
    } else {
      from = parseInt(spec, 16);
      to = from;
    }
    if (Number.isNaN(from)) continue;
    for (const point of codepoints) {
      if (point >= from && point <= to) return true;
    }
  }
  return false;
}

async function inlineFontRule(rule) {
  const src = rule.style.getPropertyValue("src");
  const match = src.match(/url\(["']?([^"')]+)["']?\)/);
  if (!match) return "";
  try {
    const res = await fetch(match[1]);
    if (!res.ok) return "";
    const bytes = new Uint8Array(await res.arrayBuffer());
    let binary = "";
    for (const byte of bytes) binary += String.fromCharCode(byte);
    const type = match[1].endsWith(".woff2") ? "woff2" : "woff";
    const data = `url(data:font/${type};base64,${btoa(binary)}) format("${type}")`;
    return rule.cssText.replace(/src:[^;]+/, `src:${data}`);
  } catch {
    return "";
  }
}

// Point the header's Sign In link back at the page it was clicked from.
//
// Upstream renders `/signin?return=<current url>` server-side. Doing that here
// would mean threading the request path through every render function and the
// layout, so it is set on load instead. The consequence is honest and small:
// with the runtime absent the link is a bare /signin and sign-in lands on the
// home page, which is where it landed before this existed.
export function wire_signin_return() {
  const doc = globalThis.document;
  if (!doc) return undefined;
  // Delegated, and in the capture phase: the account menu renders its items
  // only once open, so nothing matches at load time. Rewriting on the way to
  // the click means the link is correct whenever it exists.
  doc.addEventListener(
    "click",
    (event) => {
      const link = event.target?.closest?.('a[href^="/signin"]');
      if (!link || link.search) return;
      const here = globalThis.location?.pathname ?? "/";
      if (here === "/signin" || here === "/") return;
      const search = globalThis.location?.search ?? "";
      link.href = `/signin?return=${encodeURIComponent(here + search)}`;
    },
    true,
  );
  return undefined;
}

// Sign-In with Ethereum, against an injected wallet.
//
// The message follows EIP-4361 and its exact line order and wording matter:
// the backend parses it with a strict grammar, and it also checks `domain`
// against its own allowlist — a host that is not on that list is rejected
// even with a perfectly valid signature. That is what stops a lookalike site
// from harvesting signatures that work here, and it means this cannot succeed
// until sonic.sola.town is added to the backend's ALLOWED_SIWE_DOMAINS.
//
// The signed message and signature are posted to our own server rather than
// straight to the API, so the session cookie is set HttpOnly by the same code
// path as email sign-in instead of being held in reachable JavaScript.
export function wire_wallet_signin() {
  const doc = globalThis.document;
  if (!doc) return undefined;
  const button = doc.querySelector("#wallet-signin");
  if (!button) return undefined;

  button.addEventListener("click", async () => {
    const provider = globalThis.ethereum;
    if (!provider) {
      report("No Ethereum wallet found in this browser.");
      return;
    }
    const original = button.textContent;
    button.textContent = "Check your wallet…";
    try {
      const [address] = await provider.request({
        method: "eth_requestAccounts",
      });
      if (!address) throw new Error("No account");

      // The nonce has to come from the server: it remembers what it minted
      // and rejects a message carrying one it did not issue. A locally
      // generated random string is well-formed and is answered with
      // "Invalid or expired nonce".
      const response = await fetch("/signin/nonce");
      if (!response.ok) throw new Error("Could not start the sign-in");
      const nonce = (await response.text()).trim();
      if (!nonce) throw new Error("Could not start the sign-in");

      const message = siweMessage(address, nonce);
      const signature = await provider.request({
        method: "personal_sign",
        params: [message, address],
      });

      // A form post, so the reply can Set-Cookie and redirect exactly as the
      // email flow does.
      const form = doc.createElement("form");
      form.method = "post";
      form.action = "/signin/wallet";
      for (const [name, value] of [
        ["message", message],
        ["signature", signature],
        ["return", returnPath()],
      ]) {
        const field = doc.createElement("input");
        field.type = "hidden";
        field.name = name;
        field.value = value;
        form.appendChild(field);
      }
      doc.body.appendChild(form);
      form.submit();
    } catch (err) {
      button.textContent = original;
      // 4001 is the wallet's own "user rejected" code; that is a choice, not a
      // failure worth an error message.
      if (err?.code !== 4001) {
        report(err?.message ?? "Could not sign in with that wallet.");
      }
    }
  });
  return undefined;
}

function siweMessage(address, nonce) {
  const { host, origin } = globalThis.location;
  return `${host} wants you to sign in with your Ethereum account:
${address}

Sign in with Ethereum to the app.

URI: ${origin}
Version: 1
Chain ID: 1
Nonce: ${nonce}
Issued At: ${new Date().toISOString()}`;
}

function returnPath() {
  const params = new URLSearchParams(globalThis.location.search);
  const value = params.get("return") ?? "";
  // Same rule the server applies: same-site paths only, and `//` is
  // protocol-relative, so absolute in effect.
  return value.startsWith("/") && !value.startsWith("//") ? value : "";
}

function report(message) {
  const doc = globalThis.document;
  const slot = doc.querySelector("#signin-problem");
  if (slot) {
    slot.textContent = message;
    slot.classList.remove("hidden");
  }
}

// Escape closes any open dialog.
//
// The dialogs are CSS-only — a hidden checkbox drives them — so opening,
// closing and submitting all work with no runtime. Escape is the one part CSS
// cannot express, and it is the part people notice missing.
export function wire_dialog_escape() {
  const doc = globalThis.document;
  if (!doc) return undefined;
  doc.addEventListener("keydown", (event) => {
    if (event.key !== "Escape") return;
    for (const box of doc.querySelectorAll('input.peer[type="checkbox"]')) {
      if (box.checked) box.checked = false;
    }
  });
  return undefined;
}

function flash(button, message) {
  const original = button.textContent;
  button.textContent = message;
  setTimeout(() => {
    button.textContent = original;
  }, 1500);
}

// Fallback for a refused clipboard: put the URL somewhere the reader can copy
// it by hand instead of leaving them with a button that did nothing.
function selectText(text) {
  const doc = globalThis.document;
  const field = doc.createElement("input");
  field.value = text;
  field.style.position = "fixed";
  field.style.opacity = "0";
  doc.body.appendChild(field);
  field.select();
  setTimeout(() => field.remove(), 5000);
}
