# Run blocks in the infoview

Implementation design, based on verso-run `2365399`. This is a proposed adapter;
no infoview execution or dependency compatibility has been qualified yet.

## Author experience

An optional `VersoLeanRun.Cast` import enables a Cast preview of a Manual page.
The infoview shows the elaborated prose, highlighted source and ordinary Run
controls. Editing a function updates the code that Run executes after the page
elaborates successfully. Authors do not need to generate a website or start an
HTTP server for this loop. Imported modules still need Lean's normal preparation.

The first acceptance example contains a scalar function, an HTML function and an
imported function. Then qualify finite and live models using the same adapter.
Manual is the first genre; Blog and Slides can reuse the execution transport
with their own Cast extension decoders.

## Existing pieces

| Responsibility | Existing implementation | Integration |
| --- | --- | --- |
| Checked document and edits | Cast's reference-manual preview RPC and refresh effect | Use the end-of-document checked snapshot; keep its URI and version with the response. |
| Document rendering | `VersoCast.Manual.createRenderers`, `Renderer.Renderers.renderBlock?` | Recognize `VersoLeanRun.Block.leanRun`, decode its `Experiment`, and render its children through Cast. Delegate other extensions to the Manual renderer. |
| Runnable metadata | `Experiment`, `Experiment.browserDescription`, `Collect.experiments` | Select callables from the checked document rather than accepting arbitrary names from the browser. |
| Current executable code | VIR `prepareWidgetPackage`, built on `prepareSnapshotInput` and imported-owner resolution | Analyze the selected callable in the same live environment as the document. Emit package bytes on demand. |
| Infoview byte transport | VIR `readAsset`, `base64Encode`, RPC cancellation | Load the locked runtime through RPC and send current package bytes through an execution RPC. |
| Invocation and Stop | `ExperimentHost`, `worker.js`, `contract.js` | Supply an editor transport to the existing host; keep one worker per running placement. |
| Result presentation | `ViewHost`, compiled Lean presenter, `AutomatonPlayer` | Supply presenter acquisition through the same editor transport. Keep current HTML isolation and playback semantics. |

VIR's snapshot API accepts an arbitrary executable root; it is not limited to
React component factories. Its pinned tests already cover unsaved module edits,
private helpers and imported owners. This is source evidence for the design,
not a newly executed integration test. In particular, current-page IR need not
come from the last successful Lake build.

## Document and execution requests

Use two RPC methods, with names and record definitions finalized during the
first implementation slice:

```text
preview(position) -> { uri, version, documentJson }
program({ version, document, declaration })
    -> { uri, version, callable, fingerprint, expectedExport, packageBase64 }
```

`preview` follows Cast's existing pattern: wait for the page's final snapshot,
wait for its checked environment, evaluate the document, then serialize its
`Part Manual`. The current decoder can carry Manual's JSON extension data; the
new generated-codec work is not a prerequisite.

`program` obtains a checked snapshot for the requested page and requires the
exact requested version. It re-collects the page's admitted Run entries and
resolves the selected document/declaration to its `Experiment.callable`.
It then uses VIR's snapshot analyzer and binary emitter. The expected callable
signature comes independently from the admitted Run form, as it does in site
publication. The client checks the response identity before worker creation.

A changed document version produces a refresh response/error, never code from
a different revision under the old visible source. The handler must not re-run
the Lean frontend, start Lake, change compiler scheduling, or read the current
module's saved IR in place of its live IR. Initial implementation may analyze
on every Run; add caching only after measurements justify it. Cursor motion
alone must not fetch or package the page again.

Presenter acquisition selects the existing fixed presenter roots, with their
existing expected signatures. It uses the same runtime identity and program
loader as the entry. It does not import a document-owned resource carrier into
that document.

## React and execution ownership

Cast renders the source and surrounding document. A stable Run component owns
one imperative console container. The existing enhancer owns controls and
result DOM inside that container, and returns its existing disposal handle.
React must not also reconcile nodes mutated by the enhancer or presenter.
Component effects attach and dispose the enhancer; Cast rendering callbacks
remain hook-free.

Create component factories once, as Cast's extension contract requires. Preserve
Cast's supplied identity/focus attributes. Repeated placements of one callable
remain independent. Use explicit authored identities when available and Cast's
positional fallback otherwise; do not invent an identity from only a declaration
name. A snapshot version is an execution freshness token, not a React key.

On a document edit, immediately stop pending/running execution and mark retained
content stale. The last successful document can remain visible while the new
page elaborates, but its controls cannot run until its version is current.
This conservative first policy also stops examples after prose edits. Cursor
updates preserve controls and input. Page changes and unmount dispose owners;
stale RPC replies cannot restore them. Refresh never starts an example.

## Small shared boundaries

Keep site publication and the current default browser behavior. Introduce an
optional execution backend at three existing boundaries:

```text
enhance(element, backend = siteBackend)
ExperimentHost(description, onState, backend = siteBackend)
ViewHost(element, kind, onError, backend = siteBackend)
```

The backend acquires a placement's program/presenter and creates its worker;
the host retains request IDs, cancellation and UI state. The site backend keeps
the current publication plan and URLs. The infoview backend uses RPC, a bundled
worker bootstrap and a compiled Wasm module. Worker code keeps input decoding,
invocation, session handling and result formatting; only program opening varies.
Freeze the final backend surface after the scalar experiment rather than
generalizing it in advance.

### Contract against typed result presenters

The shared-file implementation must build on #22's placement owner, inspected at
`189514025eec7ad8b644e985d7f9c826bffdb131`. The proposed interface is deliberately
below that owner:

```text
Lease<T> = { promise: Promise<T>, release(): void }

PlacementBackend.acquireCall(description, signal): Lease<CallResources>
PlacementBackend.createWorker(): Worker
PlacementBackend.acquireView(kind, signal): Lease<ViewResources>

CallResources = { programRequest, resultRendererUrl? }
ViewResources = { program, declaration, commitDeclaration? }
```

`programRequest` is structured-cloneable data. The site variant contains current
publication URLs/contracts; the editor variant contains the snapshot identity,
package bytes, independently expected contracts and prepared runtime input.
The backend performs RPC before posting to the worker. Workers do not receive an
RPC session or a React handle. The worker's program-opening helper consumes the
variant; its invocation/session/normalization loop remains shared.

`release` is idempotent and releases an acquisition interest, including a pending
RPC. It does not dispose a successfully handed-off program. `ExperimentHost`
owns each worker and its termination; `ViewHost` owns each acquired presenter
program and its disposal. Cache only immutable bytes or compiled Wasm modules,
scoped to project/runtime and snapshot identity. Each placement gets its own
mutable program, and posting must not detach cached buffers. Every consumer keeps
its existing post-await generation checks, including late success after abort.
The caller owns request abort/deadline signals; a backend cannot extend them.

`renderer.js` keeps all Run/Restart/Stop controls, visibility transitions, result
events and disposal. A backend does not get status callbacks or mount UI.
`ResultView` keeps its persistent result slot, `mount`, `show`, `clear`, `pause`
and `dispose` contract. Supplying a relocated `resultRendererUrl` must not give
that renderer access to the placement controls. Worker normalization keeps #22's
owned-copy and reachable-transfer-buffer checks.

Cast must bind the backend before the element can be discovered by #22's global
reconciliation observer. An infoview context marker prevents automatic site
enhancement while this binding is absent. Reattachment looks up the same
per-element binding and creates a fresh idle owner. It must never fall back to
site publication URLs. Reject changing the backend beneath an existing owner;
dispose and attach explicitly when the snapshot binding changes. React ref/layout
setup and the observer ordering need a regression test.

Custom result modules need the same explicit registration used by publication;
the `CustomResult` type marker alone does not identify JavaScript assets. Preview
setup must supply those registrations before claiming custom-result support.
The first scalar/HTML slice does not invent a second registration mechanism.

The design branch can remain based on main. Compatibility experiments stay in
isolated modules/outputs. Agree this surface and the implementation writer with
#22's owner before changing the shared files; then stack the runtime patch on
the selected #22 revision, or rebase onto its landed squash. A separate preview
controller or a fork of `ResultView` is not part of this proposal.

Two VIR seams need a focused experiment before deciding on upstream changes:

1. **In-memory program opening with expected contracts.** The public runtime
   factory already accepts `wasmModule` and package bytes. The site's higher-level
   `createProgram` additionally checks independently expected signatures and
   returns an owned program facade, but requires HTTP(S) resource manifests.
   Prefer a small public in-memory entry sharing that contract validation,
   installation and disposal code. Its compatibility check must bind the package
   compiler identity to the selected runtime. Do not weaken the site loader's URL
   policy or copy its signature comparison into verso-run.
2. **Composing the infoview shell.** VIR already constructs a compiled React
   component with native infoview props. The Run component can be supplied as a
   native React prop to the Cast factory. If consumers cannot import the shell
   through a supported package export, expose that entry upstream. Keep its
   runtime lifecycle in VIR rather than copying the widget loader into verso-run.

Build the infoview module and worker from the selected VIR dependency's public
JavaScript entry points. Keep React and infoview external through the editor's
existing import map. A blob worker bootstrap can carry bundled code and receive
Wasm/package bytes; it needs no relative module imports. Actual VS Code worker
and CSP behavior must be tested, not inferred from a localhost browser harness.

Cast already has the renderer extension point. No Cast traversal fork or new
document interchange format is needed for this design. Any reusable preview-shell
extraction can be proposed to Cast after the initial integration establishes the
required surface.

## Dependency baseline

The isolated task is `feat/cast-infoview` in `.worktree/cast-infoview`. Its root
Lean, Verso, VIR, Illuminate and Slides pins remain unchanged.

Public Cast main is `5fc470057e929c849840919b0294e7e2418461ad`, using Lean
4.35.0-rc4. The separately owned local Cast checkout is clean at `0e2bc83`, three
commits ahead; it uses Lean 4.36.0-rc1, Verso `f7a4dc6` and VIR `5a5614b`.
verso-run uses Lean 4.36.0-rc1, Verso `d0a5f92` and VIR `bf8b6a8`.
Matching Lean versions alone does not establish compatibility.

First compile the needed Cast core/Manual modules against verso-run's existing
pins in an independently owned experimental consumer. Do not share writable
dependency or build directories. If incompatibilities require an upstream
change, make that change in a separate task worktree and qualify an immutable
published revision before adding the adapter dependency. The generated Manual
codec is optional and must not force a VIR upgrade for the initial integration.
Do not modify the existing Cast checkout or the documentation/presenter branches.

## Implementation slices and acceptance

1. **Compatibility and transport experiment.** Compile the minimal Cast renderer
   against the selected pins. Open a checked live scalar package in a worker
   using RPC-delivered bytes and an independently expected signature. Check an
   unsaved edit, a signature mismatch, explicit Stop during a long call, and
   retry. Use this result to settle the two VIR API seams above.
2. **Manual adapter.** Add optional `src/cast` modules for rendering, preview RPC
   and widget setup; keep their Lake ownership separate. Display actual inline
   and imported sources. Qualify scalar and escaped HTML results in the real
   infoview, with no HTTP server and no document website build.
3. **Existing views and lifetimes.** Connect `ViewHost` to the backend; qualify a
   finite sequence and a live automaton. Check independent repeated placements,
   held loading, Stop/retry, document edits, page switches, visibility and
   unmount. Late results must never commit into the replacement document.
4. **Consumer acceptance.** A fresh consumer owns its source, dependencies and
   outputs. Record exact source/runtime/package identities and exercise a real
   editor/LSP connection. Controlled browser replay supplements that check;
   it does not replace it. Run `lake build`, then `lake test -- --mutations`
   sequentially, plus focused infoview checks, before marking implementation
   ready. Add Blog/Slides decoders after this shared path works.

No implementation size or latency is claimed yet. The evidence narrows the work
to a rendering adapter, an editor execution backend and small shared VIR seams;
live compilation infrastructure is already present.

## Source references

- [Cast renderer extension contract](https://github.com/ejgallego/verso-cast/blob/5fc470057e929c849840919b0294e7e2418461ad/doc/RENDERING.md)
  and [checked-page RPC](https://github.com/ejgallego/verso-cast/blob/5fc470057e929c849840919b0294e7e2418461ad/tests/reference-manual/CastManualPreview/Server.lean).
- [Pinned VIR snapshot and package API](https://github.com/ejgallego/lean-vir/blob/bf8b6a80a5d4011ffd6804fb7a395b9cd2d0d668/Vir/Infoview/Package.lean),
  [asset RPC](https://github.com/ejgallego/lean-vir/blob/bf8b6a80a5d4011ffd6804fb7a395b9cd2d0d668/Vir/Infoview/Assets.lean),
  and [live-snapshot fixtures](https://github.com/ejgallego/lean-vir/blob/bf8b6a80a5d4011ffd6804fb7a395b9cd2d0d668/fixtures/infoview/Smoke.lean).
- [Run block metadata](../src/authoring/VersoLeanRun/Model.lean),
  [Manual block](../src/manual/VersoLeanRun/Manual.lean),
  [execution host](../web/host.js), [worker](../web/worker.js),
  and [presenter host](../web/presenter.js).
