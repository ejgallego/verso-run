# When an example cannot run

There are three different places an error can occur: the author’s Lean code,
resource preparation/publication, or the reader’s browser. Start with the first
error in the build log; later errors may be consequences of it.

## The function does not fit a Run form

VIR supports more interfaces than this extension currently presents. For example,
a `Bool → Bool` function is a valid VIR interface, but a Run form accepts only
pure, monomorphic `String → String`, `Nat → Nat`, or `String → Html` functions
with one explicit argument.

The diagnostic names the entry, shows its type, and explains the form restriction:

```text
Lean Run entry 'flag' has type Bool → Bool.
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
Interface rejection is diagnosed before a missing export marker so adding a
marker is not offered as the cure for an unsupported type.

## The definition is not executable or registered

Use an executable public definition instead of a theorem, axiom, private entry,
or `noncomputable` value. Proofs and noncomputable choices do not supply executable
IR. Scalar functions need `@[vir_export]`; typed HTML functions are adapted and
marked automatically.

If an attribute is already present but the entry is not registered, address its
earlier VIR validation error first. Failed compilation or an unsupported reached
dependency can prevent the marker from being installed.

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

## The generator cannot find an export

Check that the declaration is in the resource recipe and that the generator
registers its embedded bundle with `VersoLeanRun.publish`. For typed HTML, the
recipe selects `<entry>.leanRunHtml`; the block still selects the original entry.

Register each declaration in one bundle/role. A mismatched `interfaceId` error
shows the expected and found values. Use `verso-string-string-v1` for text and
typed HTML, or `verso-nat-nat-v1` for natural numbers. The
[starter](../examples/manual-starter/README.md) shows complete wiring.

Rejected registration does not produce a new successful `publication.json`.
When using an existing output directory, the previous accepted plan is preserved.

## The reader sees a failure

Invalid natural-number inputs are rejected before invocation. Use non-negative
decimal digits; signs, spaces, fractions, and exponent notation are not accepted.
An input edit clears old results. Stop interrupts the worker, and another Run
creates a fresh instance.

Resource or runtime errors appear as plain text with the selected declaration,
a next step, and the original diagnostic details. HTML previews are cleared on
failure. Choose Run to retry; failures are never replayed automatically. If the
problem persists, contact the document author with the details shown.

On GitHub Pages, the current frozen loader rejects the server’s
`application/javascript` MIME type. Use the local Python server while the public
matching runtime update is pending. This is a hosting/runtime issue, independent
of the example’s Lean type; see [hosting](hosting.md).
