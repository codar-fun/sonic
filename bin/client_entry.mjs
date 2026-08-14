// Browser entry. Kept out of the Gleam build output so its path is stable
// across compiler versions, same reason as bin/server.mjs.
import { main } from "./sonic/client.mjs";
main();
