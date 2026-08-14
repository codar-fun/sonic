// Browser-only FFI.
//
// Kept apart from sonic_ffi.mjs because that one imports node:http and node:fs.
// A browser loading it fails on those imports, so the split is not tidiness —
// it is what makes the client bundle loadable at all.

export function signed_in_flag() {
  const root = globalThis.document?.querySelector("#account-menu");
  return root?.dataset?.signedIn === "true";
}
