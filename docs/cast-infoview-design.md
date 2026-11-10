# Run blocks in the infoview

The optional `VersoLeanRun.Cast` adapter previews Manual pages and connects Run
controls to live-snapshot package generation. This implementation is stacked on
#22's native placement owner at `189514025eec7ad8b644e985d7f9c826bffdb131`.
The current demo covers scalar calls, including imported source anchors.
[Demo preparation and validation](../demo/infoview/README.md) describe the local
rc2 runtime selection and the remaining editor acceptance work. The PR stays a
draft until these gates and portable dependency acquisition are resolved.

Cast owns page acquisition, decoding and document rendering. The native host
owns one selected page's abort signal; Run owns independent execution workers.
The implementation uses Cast's `Bridge {decode, view}` and public native request
hook. Earlier preview contracts remain historical evidence only.

## Preview state and lifetime direction

Cast application state and UI should remain Lean/VIR-authored. The current
JavaScript `usePage` helper and copied editor host are provisional qualification
scaffolding; they are not the preview interface to stabilize. Keep their scope
fixed while retaining the existing demo and editor acceptance as baseline evidence.

The canonical VIR request `CAST-VIR-LEAN-PREVIEW-LIFETIME-20261109-001` seeks an
existing-API example, or the smallest missing native cleanup/retired-callback
primitive, for Lean-authored React effects. It does not request a whole-preview
service or framework. Mandatory worker cleanup must still work without a healthy
Wasm callback. Consumer migration follows an agreed immutable upstream handoff;
this direction does not select new pins or a parallel upstream implementation.

## Author experience

An optional `VersoLeanRun.Cast` import enables a Cast preview of a Manual page.
The infoview shows the elaborated prose, highlighted source and ordinary Run
controls. Editing a function updates the code that Run executes after the page
elaborates successfully. Authors do not need to generate a website or start an
HTTP server for this loop. Imported modules still need Lean's normal preparation.

The first demo contains inline scalar calls, an imported function and repeated
placements. HTML, finite and live views require presenter acquisition through
the same backend before they can be qualified in the editor.
Manual is the first genre; Blog and Slides can reuse the execution transport
with their own Cast extension decoders.

## Existing pieces

| Responsibility | Existing implementation | Integration |
| --- | --- | --- |
| Checked document and edits | Cast's optional `Preview.Server.document` and native `usePage` helper | Use the final checked snapshot; the native host owns edit/restart invalidation. |
| Document rendering | `VersoCast.Manual.createRenderers`, `Renderer.Renderers.renderBlock?` | Decode the Run wrapper; reuse the successor's `Manual.Block.lean` decoder and existing highlighting. |
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

Reuse Cast's optional checked-page acquisition and add one Run-specific request.
The native reference stays outside the document JSON codec.

```text
VersoCast.Manual.Preview.Server.document({ expectedVersion? })
    -> { uri, version, snapshotRef, documentJson, hasErrors }
VersoLeanRun.Cast.Server.program({ snapshotRef, document, declaration })
    -> { uri, version, callable, fingerprint, expectedExport, packageBase64 }
```

`document` follows Cast's existing pattern: wait for the page's final snapshot,
wait for its checked environment, evaluate the document, then serialize its
`Part Manual`. The current decoder can carry Manual's JSON extension data; the
new generated-codec work is not a prerequisite. Use the public `withPage` helper
to capture `Page` metadata, environment, options, document and complete error
fact within one request. The endpoint retains this checked page through
Lean's existing `WithRpcRef` mechanism and returns the opaque handle alongside
the existing JSON string and URI/version. The environment remains server-side,
in a session-scoped RPC object rather than a persistent module extension. Drop
old client references when replacing or unmounting the page, using the existing
RPC session's reference lifecycle. Keep the reference in the native RPC envelope:
do not put it through the document String codec, clone its reserved fields or
reconstruct it from an object ID.

The opt-in server helper and `Page` record live in
`VersoCast.Manual.Preview.Server`. `VersoCast.Manual.Preview.create` returns a
stable `Bridge {decode, view}`. Native React composes `usePage(selection,
bridge.decode)` and `renderPage(bridge, state)` from `verso-cast/preview`.
Neither optional module enters core or ordinary Manual imports.
Reference-manual-specific roles remain consumer-owned.

`program` accepts that checked-page reference, checks its page identity and the
current requested version using `requireErrorFree` / `requireMatchingVersion`,
then selects an entry from its admitted Run blocks.
It resolves the document/declaration to its `Experiment.callable`.
It then uses VIR's snapshot analyzer and binary emitter. The expected callable
signature comes independently from the admitted Run form, as it does in site
publication. The client checks the response identity before worker creation.
It does not re-evaluate a different environment by looking up only the version.
The reference identifies captured data; it does not establish that the captured
page is still current. Use request-relative URI/version and cancellation checks,
plus standard session/reference validity. Do not retain scheduler pointer
identities or the whole `EditableDocument` as a freshness mechanism. The host
must abort the selected page's lifetime on supported invalidation, including
an invalidation during package preparation, and ignore late results.

The supported contract follows the pinned Lean worker: nonempty `didChange`
updates the document and cancels pending requests as edits; versions are assumed
monotonic by the client/protocol. Re-entering import setup requests a worker
restart because imports cannot be unloaded in that process. A same-URI,
same-version close/reopen therefore needs a new selection and session; old native
session/reference pairs must fail rather than become usable in the replacement
worker. Qualify that path with the real worker restart, not a substituted-context
test alone. `RequestM.readDoc` reads the request's captured context, so checking
it again is not a global latestness lease against future edits.

Same-version plugin reprocessing within a surviving session is outside this
bounded contract. Supporting such a mode would require an explicit upstream
processing stamp. It does not justify a stamp or pointer workaround for the
supported edit/restart lifecycle.

Waiting for `env.checked` does not establish that the page has no errors. The
initial Run admission policy requires a completed page with no error-severity
diagnostics; warnings alone do not disable Run. Cast reports preview/error facts;
verso-run makes this execution decision independently. Refuse error-bearing or
incomplete pages even if they can still be displayed. Keep last-good prose
visible with execution disabled after selection abort. The
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
transport is required. The native host aborts and replaces its selection after
server-session replacement, processing and ordinary source edits. Imported-module preparation remains Lean's responsibility.

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

Each selected page retains the native reference and its owning session. Stable
Run children bind to that captured selection and send program requests through
that exact session. The host owns one ordinary abort signal for the selection;
source/reprocessing/session invalidation aborts it before replacement acquisition.
Cast consumes that lifetime rather than maintaining a second didChange/generation
state machine. Acquisition and request cleanup live in native React, independently
of the Lean decoder/view and demo chrome. The renderer receives immutable
`PageInfo` and a derived `matchesSelection`; the old selected page must not match
the replacement merely because its URI/version are equal. Native execution guards
also check the captured signal directly, even if the Wasm view has not rerendered.

In native React, bind the displayed snapshot's `state.lastGood.selection` around
`renderPage`, for example through a context consumed by the native Run placement.
Do not bind the replacement `selection` around retained old prose. The placement
keeps that original signal and the `PageInfo` session/reference; its effect
subscribes native disposal directly to abort and also disposes on unmount.
Check the signal before invocation and after asynchronous acquisition, and keep
the independent runnable-entry/signature checks on the server and loader.
The derived rendering flag alone is insufficient: synchronous abort can precede
a React commit, so a retained event handler must already refuse execution.
An error-bearing page may match the selection and remain visible; its native
controls also check `PageInfo.hasErrors`. Server admission remains authoritative.

Mandatory cleanup belongs to native placement ownership: stop workers, abort
acquisition and release native resources even if a Wasm callback is unavailable
or fails. A best-effort Cast/Lean UI callback must not be the only path to
termination. Per-placement Stop remains independent of the document selection
lifetime, so stopping one example does not retire the other examples. Keep a
cursor-independent session at a position where imported RPC methods are available;
position-session object identity is not a freshness signal.

The console's markup comes from the existing `renderControls experiment`,
serialized into its imperative DOM slot. The source remains a separate,
React-managed child rendered by Cast's existing Manual/highlighting adapter.
Only the Run wrapper connects these two pieces. Do not maintain a second JSX
implementation of the form, a second source highlighter or a second HTML-result
isolation policy.

### Run source decoder

Cast's successor adds the external-code decoder needed for the source
constructor that Run emits, alongside the distinct inline Lean decoder:

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
name. Use the snapshot version in request checks, never as the React key.

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
The scalar experiment selects the backend surface below; presenter acquisition
remains a separate qualification gate.

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

The implementation is stacked on the agreed #22 revision above. The integration
lane owns the bounded backend changes; #22 remains frozen for coordinator
landing. A separate placement controller or fork of `ResultView` is unnecessary.

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
   every operation owns a separate program instance. VIR `a41f9257` supplies this
   API. Actual inline and anchored packages execute through it on rc2 with the
   source-paired runtime below. Keep the site loader's URL policy and reuse
   VIR's signature checks.
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
document interchange format is needed for this design. Its successor provides
optional checked-page acquisition separately from reference-manual-specific
roles and demo chrome. The host supplies the
selection lifetime; renderer factories stay stable and late acquisition results
are ignored after abort. Keep reference routing and last-successful prose without
a second stored freshness flag or precommit loaded callback.

The useful upstream changes are therefore specific:

| Project | Improvement | Priority |
| --- | --- | --- |
| Cast | Public checked-page acquisition with captured references, separate from demo chrome | Reuses preview/error facts under one host-owned selection lifetime. |
| Cast | Decoder for standard `Manual.Block.lean` source data | Required to show inline and anchored Run source through existing highlighting. |
| VIR | Public in-memory program opening sharing expected-signature validation and owned-program disposal | Keeps editor and site execution on one callable contract. |
| Consumer | Qualify the existing registered widget-module import | Reuses the VIR shell without a new npm export or copied loader. |
| VIR | Cooperative cancellation checkpoints in existing byte/package RPC handlers | Useful bounded follow-up; not a new protocol or a prerequisite for worker Stop. |

Cast supplies the preview API. Real producer tests exposed a flat-array decoder
bug in `6bee7e7`; the frozen source correction renders both producer forms in the
actual editor, while publication remains an adoption gate. VIR's owned-program
API passes the actual-byte execution gate below. No additional Cast RPC or client
hook is required by this ownership review.

## Dependency baseline and acceptance

This task lives in `.worktree/cast-infoview` on `feat/cast-infoview`.
The selected compiler is Lean **4.36.0-rc2**, revision
`b35cb10cf2ced51a2fd1880cfdbf75c71ab7a35a`. Verso `d0a5f92`, Illuminate
`d22e76e` and Slides `e7705d5` remain unchanged. VIR is
`a41f9257f5d34911d5b1f53dba37c2e1bc022aae` from
[VIR PR #278](https://github.com/ejgallego/lean-vir/pull/278).
Cast's selected preview API is from [Cast PR #1](https://github.com/ejgallego/verso-cast/pull/1),
base `6bee7e7e06546cef75ee873bbe7e6252151e0432`. Its flat source decoder and
reference-host status-clear corrections are qualified from the owner's frozen
source snapshot: patch SHA256
`61292bad52a03611058aa22fa126c6cac9d866fb045e920ef3d3612828077765`, archive SHA256
`b012bb7cd1984b717e374cfedeab37b09cdca7d9b9850cd2038bc1d4908e2e0a`.
Their signed publication remains pending. The source compiles against this
consumer's dependencies; no Cast binary outputs, runtime or SDK is copied.

The matched local runtime has content ID
`a5001decce3979891e263a0843e8c76392c493ee9daf88ad1b2fbdd3233b8666`, pack SHA256
`9ef8cf1012250cd47cb09eff65f5ad8493e8a7ba8225756769bec4972f6c80a7` and release
Wasm SHA256 `1ab2ecd05abdaaac3dd2e3c704200892b78caa918a97d67a7e212220f85db6a5`.
This is an exact-source local qualification input. The selected public VIR lock
still names an unavailable release; local demo preparation uses a private source
clone at lock-only local commit `3d01e51718307165e02c0c66178b9360fb4d5f19`,
whose direct parent is the selected API source, and Lake's supported workspace
package override. The SDK/API identity remains `a41f9257`; the local commit only
selects the qualified relative runtime input. Normal public acquisition remains
a landing gate.

The new tests distinguish these results:

| Gate | Evidence and scope |
| --- | --- |
| rc2 source builds | Verso, preview server, compiled adapter and real Run producer fixture compile. |
| Actual producer layout | `CastSources.lean` checks the flat external-source payloads from both `leanRun` and `leanRunAnchor`. A nested product decoder is insufficient. |
| Actual package generation | `CastPackages.lean` uses VIR's public analyzer/emitter for the real inline and imported roots. |
| Actual Wasm calls | `cast-byte-program.mjs` invokes both packages, checks pre-await input snapshots, independent disposal and post-disposal refusal. |
| Native placement lifetime | Controlled Chromium tests use the production native wrapper and hosts: exact captured ref routing, pending Stop, late replies, independent workers, edits, unbound reconciliation and cleanup after a failing Lean view. The peer and worker are controlled. |
| Site behavior | `lake build` and all 101 checks in `lake test -- --mutations` pass with the disclosed local selections. The focused sequence suite also passes all 28 checks, including signature mismatch/retry. |
| Actual VS Code | Real inline/anchor source highlighting, scalar calls, repeated placements, cursor movement without a new header-session RPC and long-running worker Stop pass. Interactive assertions also observed unsaved execution, stale/unadmitted-root refusal and error-bearing preview/admission. The complete edit/recovery driver timed out during final restoration; same-version close/reopen and recovery remain open consumer gates. |

Generated logs, packages and results live under `_out/rc2-demo/`,
`_out/cast-demo/` and `_out/cast-placement/`. Generated widget/runtime files stay
out of Git. These are qualification outputs, rather than a public runtime release.

Historical source-only consumers remain under `_out/cast-compatibility/` and
`_out/cast-preview-{27085ea,9701d6f,6bee7e7}/`. Their recorded rc1 results apply
only to their own revisions; any local edits are preserved. Their source-only drivers remain in the
[historical checkpoint](https://github.com/ejgallego/verso-run/tree/9d0b403e39bee29c9ab8368d8311571035c3413d/experiments/cast-compatibility).
The current branch replaces that scaffolding with the optional adapter and
focused tests. Use the [demo setup](../demo/infoview/README.md) for rc2.
