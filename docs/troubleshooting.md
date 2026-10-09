# When an example cannot run

There are three different places an error can occur: the author’s Lean code,
resource preparation/publication, or the reader’s browser. Start with the first
error in the build log; later errors may be consequences of it.

## The function does not fit a Run form

VIR supports more interfaces than this extension currently presents. For example,
an `Int → Int` function is a valid VIR interface, but a Run form accepts only
pure, monomorphic `String → String`, `Nat → Nat`, `Bool → Bool`,
`UInt64 → UInt64`, or `String → Html` functions
with one explicit argument.

The diagnostic names the entry, shows its type, and explains the form restriction:

```text
Lean Run entry 'signedIdentity' has type Int → Int.
This interface is supported by VIR, but not by this Run form.
```

Use a wrapper that parses one text input and returns text or typed HTML. For a
multi-argument function, the wrapper can parse both values from that one input.
For effectful code, move I/O to the document build or export a pure calculation.

## VIR rejects the interface

Polymorphic or implicit arguments need a concrete wrapper with explicit runtime
types. Dependent results and some structures cannot cross the pinned runtime’s
interface boundary. The message retains VIR’s explanation rather than replacing
it with a generic failure:

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
IR. Selecting `entry` registers a scalar callable or generates a typed HTML
serializer automatically. Read the first compilation or VIR dependency error;
adding an export annotation is not a remedy for missing executable IR.

## The type is supported, but a dependency is unavailable

A `String → String` entry can still call an operation missing from the locked
runtime. VIR checks the compiled dependency closure, including helper functions.
Its errors identify the exported declaration and blocked dependency. Replace that
operation, choose a supported path, or wait for a compatible VIR provider update.

For example, general Illuminate diagram rendering reaches `Float.toBits`,
`Float.atan`, or `Float.asin` on the frozen runtime. The demo uses the qualified
drawing-command/SVG path instead. See [the recorded gates](../evidence/illuminate-gates.md).

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

Each document root exposes entries selected by its Run blocks, including
generated wrappers for imported functions and typed HTML. Imported producers
supply dependencies; the callable wrapper belongs to the document's bundle. At Run, `createProgram` checks the selected full declaration
and independent signature before invoking Lean. A missing root declaration or
signature mismatch belongs to program validation, not a native recipe check.
The [starter](../examples/manual-starter/README.md) shows complete wiring.

Rejected native registration does not produce a new successful `publication.json`.
When using an existing output directory, the previous accepted plan is preserved.

## The reader sees a failure

Invalid natural-number inputs are rejected before invocation. Use non-negative
decimal digits; signs, spaces, fractions, and exponent notation are not accepted.
An input edit clears old results. Stop interrupts the worker, and another Run
creates a fresh instance.

A stopped call settles immediately even while the publication is loading. Other
placements can keep their shared fetch; cancelling the last waiter lets the next Run
acquire afresh. Publication acquisition fails after 15 seconds rather than waiting
indefinitely. Choose Run to retry; acquisition failures are not cached.

Resource or runtime errors appear as plain text with the selected declaration,
a next step, and the original diagnostic details. HTML previews are cleared on
failure. Choose Run to retry; failures are never replayed automatically. If the
problem persists, contact the document author with the details shown.

The selected public runtime accepts GitHub Pages' JavaScript MIME spelling while
retaining payload integrity checks. Hosted deployment qualification is recorded
separately from local acceptance; see [hosting](hosting.md).
