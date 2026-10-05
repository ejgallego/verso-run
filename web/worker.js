// One worker owns one VIR program. Terminating this worker cancels synchronous calls.
import { expectedExport, validateInput, formatResult } from "./contract.js";
let program = null;
let description = null;
let creating = null;
function diagnostic(error) {
  const parts = [];
  for (let current = error, i = 0; current && i < 5; current = current.cause, i++) {
    parts.push(String(current.message ?? current).slice(0, 1000));
  }
  if (error && Object.hasOwn(error, "cleanupError")) parts.push("Cleanup: " + String(error.cleanupError));
  return parts.join(": ");
}
onmessage = async ({ data }) => {
  const { requestId } = data;
  try {
    if (data.operation !== "invoke" || creating) throw new Error("Invalid or overlapping worker request");
    validateInput(data.description.shape, data.input);
    if (!program) {
      description = data.description;
      const { createProgram } = await import(data.publication.runtimeModule);
      creating = new AbortController();
      program = await createProgram({
        runtimeManifestUrl: new URL(data.publication.runtimeManifest),
        programManifestUrl: new URL(data.publication.programManifest),
        signal: creating.signal,
        expectedExports: { [data.publication.role]: expectedExport(description) },
      });
      creating = null;
    }
    if (description.declaration !== data.description.declaration || description.shape !== data.description.shape) {
      throw new Error("Worker experiment identity changed");
    }
    postMessage({ requestId, state: "running" });
    const result = program.call(data.publication.role, data.input);
    postMessage({ requestId, state: "success", result: formatResult(description.shape, result) });
  } catch (error) {
    creating = null;
    try { program?.dispose(); } catch (cleanup) { error.cleanupError = cleanup; }
    program = null;
    postMessage({ requestId, state: "failed", error: diagnostic(error) });
  }
};
