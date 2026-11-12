// The worker has no RPC, React or editor handles. Its program inputs are bytes
// selected by the native placement backend and independently admitted by VIR.
import { createVirRuntimeFactory } from "lean-vir";
import { workerHandler } from "../worker-core.js";
onmessage = workerHandler(async (request, description, signal) => {
  const factory = createVirRuntimeFactory({ wasmBytes: request.wasmBytes,
    runtimeManifest: request.runtimeManifest, expectedRuntimeContentId: request.expectedRuntimeContentId });
  return factory.createProgram({ irPackageSet: request.irPackageSet,
    expectedExports: { [description.callable]: request.expectedExport }, signal });
});
