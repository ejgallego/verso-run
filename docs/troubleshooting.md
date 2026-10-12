# When an example cannot run

There are three different places an error can occur: the author’s Lean code,
resource preparation/publication, or the reader’s browser. Start with the first
error in the build log; later errors may be consequences of it.

## The function does not fit a Run form

VIR supports more interfaces than this extension currently presents. For example,
an `Int → Int` function is a valid VIR interface, but a Run form accepts only
monomorphic functions with one explicit argument of type `String`, `Nat`, `Bool`,
or `UInt64`. The result can be the same scalar type, `Html`, `SequenceView`, or
`AutomatonView`. Scalar, HTML, and sequence functions must be pure; live views
return an `AutomatonView` action.

The diagnostic names the entry, shows its type, and explains the form restriction:

```text
Lean Run entry 'signedIdentity' has type Int → Int.
This interface is supported by VIR, but not by this Run form.
```

Use a wrapper that parses one text input and returns text or typed HTML. For a
multi-argument function, the wrapper can parse the arguments from that one input.
Functions returning `IO` do not have a Run form. Move that work to the document
build or expose a pure calculation. Live views use the separate `AutomatonView`
action described in the authoring guide.

## VIR rejects the interface

Polymorphic or implicit arguments need a concrete wrapper with explicit runtime
types. Dependent results and some structures cannot cross the pinned runtime’s
interface boundary. The diagnostic includes VIR’s explanation:

```text
Lean Run entry 'polymorphic' has an unsupported VIR interface.
Type: (α : Type) → α → α
VIR: VIR exports must use concrete runtime types; type parameter `α` is erased;
export a concrete wrapper instead
```

Check the reported argument or result and choose a supported representation.
Interface rejection is diagnosed before automatic registration, so adding an
export marker is not offered as the cure for an unsupported type.

## The definition is not executable or registered

Use an executable public definition instead of a theorem, axiom, private entry,
or `noncomputable` value. Proofs and noncomputable choices do not supply executable
IR. The build registers the function named by `entry`, including functions
imported from another module. Read the first compilation or VIR dependency error;
adding an export annotation is not a remedy for missing executable IR.

## The type is supported, but a dependency is unavailable

A `String → String` entry can still call an operation missing from the locked
runtime. VIR checks the entry and the helper functions it calls.
Its errors identify the exported declaration and blocked dependency. Replace that
operation, choose a supported path, or wait for a compatible VIR provider update.

For example, general Illuminate diagram rendering reaches `Float.toBits`,
`Float.atan`, or `Float.asin` on the pinned runtime. The demo uses the tested
drawing-command/SVG path. See [the support limits](../evidence/illuminate-gates.md).

A failed rebuild must exit unsuccessfully and leave the previous accepted
publication intact. Its retained output represents the earlier successful build,
not the rejected replacement. CI deploys only after all checks pass.

## Resource sets disagree about their runtime

`combineResources` and `slidesMain` reject `RUNTIME_CONTENT_ID_CONFLICT`
when sets carry different runtime identities, even if their compiler compatibility
matches. Build all carriers with the same pinned VIR runtime. Manual and Blog
preserve the runtime supplied in their set; Slides uses its formatter's runtime
and requires the supplied document set to match it. Corrupt inventories retain
VIR's original validation error rather than being silently discarded.

## A program bundle or callable is missing

Add the document's module resource facet (for example,
`` `+MyChapter:virResourcePack ``) to the asset library's `needs`, and embed with
`include_vir_assets (modules := #[Module])`. Pass the returned `ResourceSet` to `VersoLeanRun.publish`. Publication reports the declaration,
callable-owning module, and document position when no matching bundle is available.
Identical bundles deduplicate; distinct bundles with the same module logical ID
produce `LOGICAL_ID_CONFLICT` before writing execution resources.

Each document's bundle contains the functions selected by its Run blocks,
including wrappers for imported functions. The source modules supply the compiled
dependencies. Before calling Lean, the browser checks that the published program
contains the selected function with the expected signature. A missing function
or a signature mismatch is reported during program validation.
The [starter](../examples/manual-starter/README.md) shows complete wiring.

If native registration fails, no new `publication.json` is accepted. An existing
output directory keeps its last successful publication plan.

## The reader sees a failure

Invalid natural-number inputs are rejected before invocation. Use non-negative
decimal digits; signs, spaces, fractions, and exponent notation are not accepted.
Input edits clear ordinary results and recorded views. Live views keep their
current state until Restart applies the edits. Stop interrupts the worker, and
another Run starts a fresh example.

A stopped call settles immediately even while publication is loading. Other
examples can continue using the shared download; if all of them cancel, the next
Run starts a fresh download. Publication loading has a 15-second deadline.
Choose Run to retry; acquisition failures are not cached.

Resource or runtime errors appear as plain text with the selected declaration,
a suggested action, and the original diagnostic details. HTML previews are cleared on
failure. Choose Run to retry; failures are never replayed automatically. If the
problem persists, contact the document author with the details shown.

The selected public runtime accepts GitHub Pages' JavaScript MIME spelling while
retaining payload integrity checks. Hosted deployment qualification is recorded
separately from local acceptance; see [hosting](hosting.md).
