# Run blocks in the infoview

Implementation design, based on verso-run `2365399`. Cast core/Manual and the
optional Preview public imports compile on these pins in the isolated gates
below. The adapter, package integration and actual infoview execution remain
unqualified.

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
| Document rendering | `VersoCast.Manual.createRenderers`, `Renderer.Renderers.renderBlock?` | Decode the Run wrapper and add the missing `Manual.Block.lean` source decoder described below; reuse Cast's highlighting and delegate other supported extensions. |
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

Improve Cast's existing checked-page request and add one Run-specific request.
The public Cast namespace below is proposed: today's implementation lives under
`tests/reference-manual/CastManualPreview`, not in Cast's library API.

```text
VersoCast.Manual.Preview.Server.document({ expectedVersion? })
    -> { uri, version, snapshotRef, documentJson }
VersoLeanRun.Cast.program({ snapshotRef, version, document, declaration })
    -> { uri, version, callable, fingerprint, expectedExport, packageBase64 }
```

`document` follows Cast's existing pattern: wait for the page's final snapshot,
wait for its checked environment, evaluate the document, then serialize its
`Part Manual`. The current decoder can carry Manual's JSON extension data; the
new generated-codec work is not a prerequisite. Factor this checked-page
selection/evaluation into a public server helper used by both requests. The
helper invokes its consumer with the page metadata, environment, options and
document within the request. The endpoint retains this checked page through
Lean's existing `WithRpcRef` mechanism and returns the opaque handle alongside
the existing JSON string and URI/version. The environment remains server-side,
in a session-scoped RPC object rather than a persistent module extension. Drop
old client references when replacing or unmounting the page, using the existing
RPC session's reference lifecycle. Keep the reference in the native RPC envelope:
do not put it through the document String codec, clone its reserved fields or
reconstruct it from an object ID.

Place the opt-in server helper and checked-page record in
`VersoCast.Manual.Preview.Server`, and the stable React factory in
`VersoCast.Manual.Preview`. Keep both out of core and ordinary Manual imports.
Reference-manual-specific roles remain consumer-owned.

`program` accepts that checked-page reference, checks its page identity and the
current requested version, then selects an entry from its admitted Run blocks.
It resolves the document/declaration to its `Experiment.callable`.
It then uses VIR's snapshot analyzer and binary emitter. The expected callable
signature comes independently from the admitted Run form, as it does in site
publication. The client checks the response identity before worker creation.
It does not re-evaluate a different environment by looking up only the version.
The reference identifies captured data; it does not establish that the captured
page is still current. The program handler must refuse a retired snapshot after
same-version reprocessing or session retirement, including an invalidation that
occurs during package preparation. Establish the server's authoritative
freshness check in the compatibility/lifecycle experiment before enabling Run.

Waiting for `env.checked` does not establish that the page has no errors. The
initial execution policy requires a completed page with no error-severity
diagnostics; warnings alone do not disable Run. Capture admission with the
checked page, revalidate freshness when packaging, and refuse error-bearing or
incomplete pages. Keep last-good prose visible with execution disabled. The
diagnostic/admission check and how it observes the full page require a real
server test; successful document evaluation is not a substitute.

A changed document version produces a refresh response/error, never code from
a different revision under the old visible source. The handler must not re-run
the Lean frontend, start Lake, change compiler scheduling, or read the current
module's saved IR in place of its live IR. Initial implementation may analyze
on every Run; add caching only after measurements justify it. Cursor-only
no-fetch behavior is a goal requiring a real-editor observation. RPC sessions
are position-specific: a different `RpcSession` object is not by itself evidence
that the server restarted. Use observed reprocessing/session-retirement events,
rather than object inequality, to invalidate execution.

Presenter acquisition selects the existing fixed presenter roots, with their
existing expected signatures. It uses the same runtime identity and program
loader as the entry. It does not import a document-owned resource carrier into
that document.

The existing VIR RPCs retain their responsibilities:

| Request | Decision | Reason |
| --- | --- | --- |
| `readAsset` | Reuse | Already transports project-relative binary files through the editor RPC session. No new runtime/file-download endpoint is needed. |
| `buildIRPackage` | Reuse for the preview widget's compiled UI | It selects an immutable package retained by `vir_proof_widget` using its entry and fingerprint. |
| Cast's `document` | Promote and improve | A checked page needs an explicit URI/version response and a reusable refresh component. |
| Run's `program` | Add in verso-run | Its authority comes from the requested version's admitted Run blocks, not from a retained widget definition. |

The new program handler calls VIR's existing snapshot analyzer and emitter;
it does not implement another compiler. Do not broaden `buildIRPackage` to accept
arbitrary browser-supplied roots or make Run entries masquerade as widget
definitions merely to reuse an endpoint. Execution stays in the worker, so
there is no server-side run/evaluate RPC. If another consumer later needs this
same selection contract, extract a shared selector then.

Use the existing RPC-reference protocol for the snapshot handle. No custom
server-side snapshot registry, raw Environment serialization or new reference
transport is required. Cast's shared refresh component must refresh/revalidate
its page after server-session replacement and page reprocessing, as well as
ordinary source edits. Imported-module preparation remains Lean's responsibility.

Cancellation polling around asset reads, package emission and base64 encoding
would be a small improvement to the existing VIR handlers. It should preserve
their protocols and complement the caller's abort/generation guards. It does not
make those synchronous operations preemptible or replace worker termination.

## React and execution ownership

Cast renders the source and surrounding document. A stable Run component owns
one imperative console container. The existing enhancer owns controls and
result DOM inside that container, and returns its existing disposal handle.
React must not also reconcile nodes mutated by the enhancer or presenter.
Component effects attach and dispose the enhancer; Cast rendering callbacks
remain hook-free.

The public preview's `PageInfo` retains the native reference and its owning
session. Each stable Run child binds to that captured `PageInfo` in its own
effect and sends program requests through that exact session. `onLoaded` is a
precommit reply notification, not a React commit or permission to retarget old
controls. Last-good content receives `isCurrent = false` during refresh; that
flag is local display state rather than a server freshness lease. The host must
stop owners before changing `Input.generation`, and supply a cursor-independent
session whose position makes the imported RPC methods available.

The console's markup comes from the existing `renderControls experiment`,
serialized into its imperative DOM slot. The source remains a separate,
React-managed child rendered by Cast's existing Manual/highlighting adapter.
Only the Run wrapper connects these two pieces. Do not maintain a second JSX
implementation of the form, a second source highlighter or a second HTML-result
isolation policy.

### Run source decoder

Cast's existing Manual Lean-block decoder does not cover the source constructor
that Run emits. Add the standard external-code decoder to Cast's Manual adapter
(or temporarily the Run adapter until an upstream candidate is consumable):

| Constructor | Stored JSON |
| --- | --- |
| `Verso.Genre.Manual.Block.lean` (Run source) | `[CodeConfig, Highlighted, definedNames]` |
| `Verso.Genre.Manual.InlineLean.Block.lean` (existing Cast decoder) | `[Highlighted, _, _, _]` |

Match the constructor and three-field layout explicitly, decode the stored
`Highlighted` value, and pass it to the existing `Highlighting.render` with
Cast's normal attributes/styles. Preserve the other constructor's decoder.
Both inline `leanRun` and `leanRunAnchor` emit the external-code form. Its
children are empty, so rendering fallback children cannot recover the source.
Malformed data should retain the ordinary visible fallback. Test the actual
producer output from both authoring paths, not just hand-written JSON fixtures.

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
Apply the same immediate stop/disable notification on observed page reprocessing
and session retirement, before awaiting replacement prose. Until these events
and server-side stale refusal are qualified, URI/version/ref equality must not
be treated as permission to keep execution enabled.

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
The opaque `snapshotRef` stays in the RPC session; it is not cloned into the
worker payload. Only ordinary identity metadata and executable bytes cross that
worker boundary.

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

The VIR disposition narrows the shared work to program admission and an
existing shell-consumption experiment:

1. **In-memory program opening with expected contracts.** The public runtime
   factory already accepts `wasmModule` and package bytes. The site's higher-level
   `createProgram` additionally checks independently expected signatures and
   returns an owned program facade, but requires HTTP(S) resource manifests.
   Prefer an owned-program operation on the existing factory, sharing the site's
   contract validation, installation and disposal code. Initial inputs should
   use matched Wasm bytes and the existing runtime descriptor/build identity;
   verify the payload and compare package compiler metadata before initialization.
   A bare precompiled module plus a caller-provided identity string is not proof
   of that association. Reuse compiled modules only while preserving verified
   provenance. The selected contract with VIR's API owner is:

   ```js
   const factory = createVirRuntimeFactory({
     wasmBytes, runtimeManifest, expectedRuntimeContentId,
   });
   const program = await factory.createProgram({
     irPackageSet, expectedExports, signal,
   });
   ```

   `runtimeManifest` is the existing runtime resource envelope; the expected
   content ID is independently selected by the consumer's lock/build contract.
   Snapshot the runtime inputs at factory construction and per-call package
   bytes/contracts at operation entry, before asynchronous work. Keep the
   verified bytes/module association private and shared only as immutable input;
   every operation owns a separate program instance. This API is selected for
   upstream implementation, not available on the current consumer pin. VIR's
   source branch is based on a different compiler pair; a matched immutable
   source/runtime/SDK checkpoint still needs qualification before consumption.
   Do not weaken
   the site loader's URL policy or copy its signature comparison into verso-run.
2. **Composing the registered infoview widget.** The locked infoview supports
   `importWidgetModule` and `widget_module:hash,<decimal hash>` imports. Qualify a
   registered wrapper that imports `Lean.Vir.Infoview.widget`'s default shell,
   with the import hash generated from that exact module's `javascriptHash`.
   The wrapper supplies the stable native Run component through props; the shell
   already forwards those props to its compiled root. This route needs no new
   npm export or copied loader. The controlled wrapper/import check below passes;
   real-editor acceptance remains pending.
   Normal shell unmount releases UI ownership without forcing disposal of
   callback/JSL-retained runtimes; preserve that behavior. Our explicitly owned
   workers and presenter programs retain their separate disposal owners.

Build the infoview module and worker from the selected VIR dependency's public
JavaScript entry points. Keep React and infoview external through the editor's
existing import map. A blob worker bootstrap can carry bundled code and receive
Wasm/package bytes; it needs no relative module imports. Actual VS Code worker
and CSP behavior must be tested, not inferred from a localhost browser harness.

Cast already has the renderer extension point. No Cast traversal fork or new
document interchange format is needed for this design. Promote the existing
checked-page helper and refresh component into an optional Cast infoview module,
separating them from reference-manual-specific roles. The refresh component
accepts an extension-renderer factory and a page-invalidated notification; that
notification lets the placement owner stop immediately on edits. Keep its stable
component construction, stale-reply suppression and last-successful-preview
behavior in one place.

The useful upstream changes are therefore specific:

| Project | Improvement | Priority |
| --- | --- | --- |
| Cast | Public checked-page/refresh component, with versioned responses and extension configuration | Enables reuse of the existing test-consumer preview without copying it. |
| Cast | Decoder for standard `Manual.Block.lean` source data | Required to show inline and anchored Run source through existing highlighting. |
| VIR | Public in-memory program opening sharing expected-signature validation and owned-program disposal | Keeps editor and site execution on one callable contract. |
| Consumer | Qualify the existing registered widget-module import | Reuses the VIR shell without a new npm export or copied loader. |
| VIR | Cooperative cancellation checkpoints in existing byte/package RPC handlers | Useful bounded follow-up; not a new protocol or a prerequisite for worker Stop. |

These are proposed changes, not findings that upstream implementations are
broken. The compatibility/worker experiment should determine the exact API
signatures before any of these library surfaces is committed.

## Dependency baseline

The isolated task is `feat/cast-infoview` in `.worktree/cast-infoview`. Its root
Lean, Verso, VIR, Illuminate and Slides pins remain unchanged.

Public Cast main is `5fc470057e929c849840919b0294e7e2418461ad`, using Lean
4.35.0-rc4. The separately owned local Cast checkout is clean at `0e2bc83`, three
commits ahead; it uses Lean 4.36.0-rc1, Verso `f7a4dc6` and VIR `5a5614b`.
verso-run uses Lean 4.36.0-rc1, Verso `d0a5f92` and VIR `bf8b6a8`.
Matching Lean versions alone does not establish compatibility.

The exact local Cast source candidate is
`0e2bc830bc43a88fc3ceea55616911924a0a83d6`; its existing qualification does not
establish compatibility with verso-run's pair. A read-only VIR diff suggests its
React/Infoview/Js/JSX APIs are unchanged between the two VIR revisions, but native
extern and runtime resources differ. That is source evidence, not permission to
copy runtime/SDK artifacts between those revisions.

First compile the needed Cast core/Manual modules against verso-run's existing
pins in an independently owned experimental consumer. Do not share writable
dependency or build directories. If incompatibilities require an upstream
change, make that change in a separate task worktree and qualify an immutable
published revision before adding the adapter dependency. The generated Manual
codec is optional and must not force a VIR upgrade for the initial integration.
Do not modify the existing Cast checkout or the documentation/presenter branches.

### Isolated source compatibility gate

`scripts/cast-compatibility.py` extracts only the exact Cast revision's Lean
sources into an ignored consumer under this task's `_out/`. The consumer owns
all eight dependency checkouts and their build directories. Its resolved
manifest/checkout revisions must equal this checkout's pins, and the extracted
Cast sources must retain their recorded hashes.

```sh
python3 scripts/cast-compatibility.py --cast-source /path/to/verso-cast --prepare
python3 scripts/cast-compatibility.py --cast-source /path/to/verso-cast --build
```

On Cast `0e2bc830bc43a88fc3ceea55616911924a0a83d6`, the batch build of
`Compatibility:olean` passes on the unchanged verso-run pins. The fixture imports
the complete core/Manual renderer and evaluates an assertion against the real
`ExternalCode.leanBlock` producer, confirming its constructor, three-field data
and empty children. No Cast source patch, runtime or SDK was copied. The report
and logs are under `_out/cast-compatibility/`; the fixture is in
[the experiment directory](../experiments/cast-compatibility/Compatibility.lean).
This establishes source compilation, not rendering of actual Run blocks,
runtime/native extern compatibility or a working editor connection.

### Registered shell import gate

After the source gate, build the registered wrapper and test the official
infoview loader:

```sh
python3 scripts/cast-compatibility.py --cast-source /path/to/verso-cast --shell
UV_CACHE_DIR="$PWD/.cache/uv" uv run --with playwright python scripts/cast-widget-import.py
```

`WidgetComposition.lean` registers the wrapper and derives its shell import from
the actual dependency's `javascriptHash`. Its batch build passes. The browser
driver uses the locked official infoview loader and React import map, with
controlled widget-source replies containing Lean's emitted modules. It checks
recursive hash-import loading, exact shell component identity, unchanged native
props, one stable supplied component factory, shared React hooks/state across
rerendering, and unmount of that test component. All six checks pass.

The wrapper source contains no private import or copied VIR loader. The shell
source is transported as a registered module, just as the infoview requests it.
Results and hashes are in `_out/cast-compatibility/widget-import.json`. The
experiment does not mount the VIR shell or open its runtime, connect to an
editor/LSP server, establish snapshot freshness, or qualify worker/CSP behavior.

### Public preview handoff gate

[Cast PR #1](https://github.com/ejgallego/verso-cast/pull/1) supplies exact source
`27085eaea49ee0c510335747212756391096deba`, including the external-code source
decoder and optional public client/server modules. Extend the same source-only
gate in a fresh consumer:

```sh
python3 scripts/cast-compatibility.py --cast-source /path/to/verso-cast --cast-revision 27085eaea49ee0c510335747212756391096deba --output _out/cast-preview-27085ea --prepare
python3 scripts/cast-compatibility.py --cast-source /path/to/verso-cast --output _out/cast-preview-27085ea --preview
```

On the unchanged d0a5/bf8 pins, the new public imports and
`PreviewCompatibility:olean` batch build pass (845 jobs). The fixture configures
the public factory without reference-manual roles and compiles a consumer RPC
that accepts the native `WithRpcRef CheckedPage`, refuses error-bearing pages,
and calls `requireCurrent` before and after its work. The fixture keeps the
captured native session/reference as native values. Beam reports no errors or
warnings; its workspace is dropped before the batch build.

This proves source/API compilation only. It does not execute that RPC, test
stale-ref refusal or runtime/compiler compatibility, establish the host's real
reprocessing/session mapping, or adopt Cast as a root dependency. Exact source
hashes, all eight resolved/checked-out revisions and logs are retained under
`_out/cast-preview-27085ea/`. No runtime/SDK is copied between Cast's pair and ours.

### VS Code document-preview smoke test

After the public-preview gate, prepare and open a read-only editor example:

```sh
python3 scripts/cast-compatibility.py --cast-source /path/to/verso-cast --output _out/cast-preview-27085ea --editor
code --new-window _out/cast-preview-27085ea/consumer --goto _out/cast-preview-27085ea/consumer/EditorDemo.lean:15
```

The editor files and locked bf8 runtime are prepared inside that consumer. The
entrypoint and widget package compile successfully (883 batch jobs); the asset
preparer checks the runtime's compiler identity. This enables a hands-on Cast
document preview with highlighted ordinary Lean source. Edit a sentence and
observe the infoview; press Ctrl+Shift+Enter in the Lean file if the panel is closed.

The page explicitly labels execution as unconnected. It has no Run blocks or
invocation backend, and uses a minimal position-specific read-only host. It
does not qualify the production session/generation mapping, actual Run controls,
worker Stop, or real-editor rendering merely by building or launching VS Code.
Report those observations separately from preparation.

## Implementation slices and acceptance

1. **Compatibility and transport experiment.** Compile the minimal Cast renderer
   against the selected pins. Open a checked live scalar package in a worker
   using RPC-delivered bytes and an independently expected signature. Check an
   unsaved edit, a signature mismatch, explicit Stop during a long call, and
   retry. Use this result to settle the two VIR API seams above.
2. **Manual adapter.** Add optional `src/cast` modules for rendering, preview RPC
   and widget setup; keep their Lake ownership separate. The first rendering
   check must show highlighted source from real `leanRun` and `leanRunAnchor`
   blocks with no unsupported-extension placeholder. Also cover malformed
   source data. Qualify scalar and escaped HTML results in the real
   infoview, with no HTTP server and no document website build.
3. **Existing views and lifetimes.** Connect `ViewHost` to the backend; qualify a
   finite sequence and a live automaton. Check independent repeated placements,
   held loading, Stop/retry, document edits, page switches, visibility and
   unmount. Late results must never commit into the replacement document.
   Require explicit checks for an error-bearing page, incomplete elaboration,
   same-version reprocessing, session retirement and position-only session
   changes. Observe immediate invalidation before a held replacement response,
   and server refusal of stale package requests. Real-editor evidence must
   establish cursor-only behavior; the controlled harness cannot prove it.
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
- [Pinned Verso external-code constructor and encoding](https://github.com/leanprover/verso/blob/d0a5f92ee585a92d2cd4c4904469c123f5ae5f10/src/verso-manual/VersoManual/ExternalLean.lean#L32-L37)
  and [Manual instance](https://github.com/leanprover/verso/blob/d0a5f92ee585a92d2cd4c4904469c123f5ae5f10/src/verso-manual/VersoManual/ExternalLean.lean#L212-L220).
- [Run block metadata](../src/authoring/VersoLeanRun/Model.lean),
  [Manual block](../src/manual/VersoLeanRun/Manual.lean),
  [execution host](../web/host.js), [worker](../web/worker.js),
  and [presenter host](../web/presenter.js).
