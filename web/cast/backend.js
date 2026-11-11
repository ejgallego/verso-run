import { waitForSignal } from "../lifetime.js";

export const decodeBase64 = value => Uint8Array.from(atob(value), c => c.charCodeAt(0));

// This backend retains the displayed snapshot, never a global latest reference.
export function editorBackend(page, runtime, worker) {
  const current = () => !!page.signal && !page.signal.aborted && !page.hasErrors;
  return {
    acquireCall(description, signal) {
      const controller = new AbortController();
      const joined = AbortSignal.any([signal, controller.signal, page.signal]);
      const promise = (async () => {
        if (!current()) throw new Error("Wait for an error-free current page before running this example");
        const reply = await page.session.call("VersoLeanRun.Cast.Server.program", {
          snapshotRef: page.snapshotRef, document: description.program, declaration: description.declaration,
        }, { abortSignal: joined });
        if (joined.aborted) throw joined.reason;
        if (!current() || reply.uri !== page.uri || reply.version !== page.version || reply.callable !== description.callable)
          throw new Error("The Run package does not match the displayed page");
        const wasmBytes = await runtime.bytes(page.session, joined);
        if (joined.aborted) throw joined.reason;
        if (!current()) throw new Error("The displayed page was replaced");
        return { programRequest: { wasmBytes, runtimeManifest: runtime.manifest,
          expectedRuntimeContentId: runtime.contentId, expectedExport: reply.expectedExport,
          irPackageSet: [decodeBase64(reply.packageBase64)] } };
      })();
      return { promise: waitForSignal(promise, joined), release: () => controller.abort() };
    },
    createWorker() {
      if (!current()) throw new Error("The displayed page was replaced");
      return worker();
    },
    acquireView() {
      throw new Error("This initial editor demo supports scalar results; view acquisition is not connected yet");
    },
  };
}
