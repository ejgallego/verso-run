import { presenterKey } from "./contract.js";
import { waitForSignal } from "./lifetime.js";

function publicationSource() {
  let publication;
  // Pending acquisition is shared only while a placement still needs it. A stopped
  // placement releases its interest, without aborting another placement's fetch.
  function acquirePublication() {
    if (!publication) {
      const controller = new AbortController();
      const entry = { controller, users: 0, settled: false };
      publication = entry;
      const deadline = setTimeout(() => controller.abort(
        new Error("Lean Run publication timed out. Choose Run to retry.")), 15000);
      entry.promise = fetch(new URL("./publication.json", import.meta.url),
        { signal: controller.signal }).then(async response => {
        if (!response.ok) throw new Error(`Lean Run publication: HTTP ${response.status}`);
        return response.json();
      }).catch(error => {
        // A late failure of abandoned acquisition cannot evict a successful retry.
        if (publication === entry) publication = undefined;
        throw error;
      }).finally(() => {
        entry.settled = true;
        clearTimeout(deadline);
      });
    }
    const entry = publication;
    ++entry.users;
    let released = false;
    return { promise: entry.promise, release() {
      if (released) return;
      released = true;
      if (--entry.users === 0 && !entry.settled) {
        if (publication === entry) publication = undefined;
        entry.controller.abort();
      }
    } };
  }

  return acquirePublication;
}

// Site publication and editor RPC implement the same resource/worker boundary.
// Invocation state, controls, cancellation and worker ownership stay in the host.
export function createSiteBackend() {
  const acquirePublication = publicationSource();
  return {
    acquireCall(description, signal) {
      const lease = acquirePublication();
      return { release: lease.release, promise: waitForSignal(lease.promise, signal).then(plan => {
        const binding = plan.programs[description.program]?.[description.declaration];
        if (!binding) throw new Error(`No published program for ${description.declaration}`);
        if (!binding.expectedExport) throw new Error(`No published VIR signature for ${description.declaration}`);
        const url = path => new URL(path, new URL("../", import.meta.url)).href;
        const programRequest = { runtimeModule: url(plan.runtimeModule),
          runtimeManifest: url(plan.runtimeManifest), programManifest: url(binding.manifest),
          expectedExport: binding.expectedExport };
        const key = presenterKey(description.form);
        let resultRendererUrl;
        if (key) {
          if (!Object.hasOwn(plan.resultPresenters ?? {}, key))
            throw new Error(`No registered result presenter for type '${key}'`);
          const presenter = plan.resultPresenters[key];
          programRequest.resultModule = url(presenter.workerModule);
          resultRendererUrl = url(presenter.rendererModule);
        }
        return { programRequest, resultRendererUrl };
      }) };
    },
    createWorker() { return new Worker(new URL("./worker.js", import.meta.url), { type: "module" }); },
    acquireView(kind, signal) {
      // Presenter retries read the publication again, as before. A rejected
      // signature must not pin an otherwise successfully fetched bad plan.
      const lease = publicationSource()();
      return { release: lease.release, promise: (async () => {
        const plan = await waitForSignal(lease.promise, signal);
        const presenter = plan.presenters?.[kind];
        if (!presenter?.expectedExport) throw new Error(`No published ${kind} presenter contract`);
        if (kind === "automaton" && !presenter.commit?.expectedExport)
          throw new Error("No published automaton commit contract");
        const expectedExports = { [presenter.declaration]: presenter.expectedExport };
        if (kind === "automaton") expectedExports[presenter.commit.declaration] = presenter.commit.expectedExport;
        const url = path => new URL(path, new URL("../", import.meta.url));
        const { createProgram } = await waitForSignal(import(url(plan.runtimeModule).href), signal);
        if (signal.aborted) throw signal.reason;
        const program = await createProgram({ runtimeManifestUrl: url(plan.runtimeManifest),
          programManifestUrl: url(presenter.manifest), signal, expectedExports });
        return { program, declaration: presenter.declaration, commitDeclaration: presenter.commit?.declaration };
      })() };
    },
  };
}

export const siteBackend = createSiteBackend();

export async function openSiteProgram(request, description, signal) {
  const { createProgram } = await import(request.runtimeModule);
  return createProgram({ runtimeManifestUrl: new URL(request.runtimeManifest),
    programManifestUrl: new URL(request.programManifest), signal,
    expectedExports: { [description.callable]: request.expectedExport } });
}
