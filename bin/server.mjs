// Stable entry point for the container.
//
// Gleam's own generated entry is named after the compiler version
// (gleam@@private_main_v1.18.1.mjs), so depending on it in a Dockerfile breaks
// on every toolchain bump. Importing the module and calling `main` is the same
// thing without the version in the path.

import { main } from "../javascript/sonic/sonic.mjs";

main();
