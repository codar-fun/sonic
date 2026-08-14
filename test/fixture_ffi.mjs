import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

// Compiled test modules live under build/dev/javascript/sails/, so resolve
// fixtures relative to the project root rather than to this file's build copy.
const here = dirname(fileURLToPath(import.meta.url));

export function read_fixture(name) {
  const candidates = [
    join(here, "fixtures", name),
    join(here, "..", "..", "..", "..", "test", "fixtures", name),
    join(process.cwd(), "test", "fixtures", name),
  ];
  for (const path of candidates) {
    try {
      return readFileSync(path, "utf8");
    } catch {
      // try the next candidate
    }
  }
  throw new Error(
    `fixture ${name} not found; looked in:\n  ${candidates.join("\n  ")}`,
  );
}

export function one() {
  return 1;
}
