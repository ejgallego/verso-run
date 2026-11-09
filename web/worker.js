// One worker owns one program; the host terminates it for synchronous Stop.
import { workerHandler } from "./worker-core.js";
import { openSiteProgram } from "./backend.js";
onmessage = workerHandler(openSiteProgram);
