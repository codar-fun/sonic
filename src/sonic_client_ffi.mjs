// Browser-only FFI.
//
// Kept apart from sonic_ffi.mjs because that one imports node:http and node:fs.
// A browser loading it fails on those imports, so the split is not tidiness —
// it is what makes the client bundle loadable at all.

export function signed_in_flag() {
  const root = globalThis.document?.querySelector("#account-menu");
  return root?.dataset?.signedIn === "true";
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
