// One worker owns one VIR program. Terminating this worker cancels synchronous calls.
import { decodeInput, formatPublishedResult, scalarKind, resultKind } from "./contract.js";
import { normalizeResult } from "./result.js";
let program = null;
let description = null;
let creating = null;
let session = null;
let normalizing = false;
let resultModule = null;
function diagnostic(error, declaration) {
  const parts = [];
  for (let current = error, i = 0; current && i < 5; current = current.cause, i++) {
    parts.push(String(current.message ?? current).slice(0, 1000));
  }
  if (error && Object.hasOwn(error, "cleanupError")) parts.push("Cleanup: " + String(error.cleanupError));
  const reason = parts.join(": ");
  const help = error?.phase
    ? "This example's execution resources could not be loaded or verified. Try Run again; if it still fails, contact the document author."
    : "Try Run again; if it still fails, contact the document author.";
  return `Could not run ${declaration}. ${help}\nDetails: ${reason}`;
}
onmessage = async ({ data }) => {
  const { requestId } = data;
  try {
    if (!["invoke", "advance"].includes(data.operation) || creating || normalizing) throw new Error("Invalid or overlapping worker request");
    const argument = data.operation === "invoke" ? decodeInput(scalarKind(data.description.form), data.input) : undefined;
    if (!program) {
      if (data.operation !== "invoke") throw new Error("No automaton session to advance");
      description = data.description;
      resultModule = data.publication.resultModule ?? null;
      creating = new AbortController();
      const { createProgram } = await import(data.publication.runtimeModule);
      program = await createProgram({
        runtimeManifestUrl: new URL(data.publication.runtimeManifest),
        programManifestUrl: new URL(data.publication.programManifest),
        signal: creating.signal,
        expectedExports: { [data.description.callable]: data.publication.expectedExport },
      });
      creating = null;
    }
    if (description.declaration !== data.description.declaration ||
        JSON.stringify(description.form) !== JSON.stringify(data.description.form) ||
        description.callable !== data.description.callable ||
        resultModule !== (data.publication.resultModule ?? null)) {
      throw new Error("Worker experiment identity changed");
    }
    postMessage({ requestId, state: "running" });
    let result;
    if (data.operation === "advance") {
      if (!session || typeof session.advance !== "function") throw new Error("No automaton session to advance");
      result = session.advance();
    } else {
      // Reinitialisation gets a fresh worker: no retired callback accumulates.
      result = program.call(description.callable, argument);
      if (resultKind(description.form) === "automaton") {
        if (!result || typeof result.advance !== "function") throw new Error("Lean returned an invalid automaton session");
        session = result;
        result = session.initial;
      }
    }
    if (resultKind(description.form) === "custom") {
      if (!resultModule) throw new Error("No published result normalizer");
      normalizing = true;
      const packet = await normalizeResult(resultModule, result, description);
      normalizing = false;
      postMessage({ requestId, state: "success", result: packet.result }, packet.transfer);
    } else postMessage({ requestId, state: "success", result: formatPublishedResult(description.form, result) });
  } catch (error) {
    creating = null;
    normalizing = false;
    try { program?.dispose(); } catch (cleanup) { error.cleanupError = cleanup; }
    program = null;
    session = null;
    postMessage({ requestId, state: "failed", error: diagnostic(error, data.description?.declaration ?? "this example") });
  }
};
