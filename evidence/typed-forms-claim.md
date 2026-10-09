# Typed Run forms — consumer claim

This is a historical qualification record. Its source pins and coordination
identifiers describe that earlier campaign, not the current contributor workflow.
See [internals](../docs/internals.md) for current pins and
[validation](../docs/validation.md) for current qualification.


Authority: `VIR-PR223-ALL-FINDINGS-SELECTED-20261008-001`, confirmed by the
maintainer's direct instruction on 2026-10-08.

Consumer source owner retained in `/home/egallego/lean/verso-run`, branch `main`,
base `11b5c5cdb18a526d0f0a290e651461c74587205c`. The initial working tree was clean;
no existing WIP was overwritten. Scope is concrete Bool/UInt64 forms and multiline
String presentation, shared consumer codec/worker lifecycle, and the existing
Manual, Blog, and Slides adapters. No VIR form framework is selected.

Exact source/runtime pair remains VIR `bda79d5c4ab7d061c971fcd8917f536393ec03ee`
and runtime `e415e41a43eccf298b710056efccf6c3d436d5fceb4e130fb06cb09d12d027dd`.
No PR223 source, new encoder import, or new runtime is adopted by implication.
No push, merge, or cleanup is granted for this slice.

## Schema agreement prerequisite

A concrete proposal was queued to the sole native encoder owner, session
`01a11711-6dbb-7fa0-8094-596ae0e9bfbd`, before implementation:
queue message `01a11b28-d63a-77c3-8dd8-67b8d190daf2`.

Proposed expectation is the accepted type-only schema: `args` is an ordered array
of canonical InterfaceType descriptors, `result` is one descriptor, and `effect`
is its canonical label. No binder names, export names/IDs/aliases, implementation
slots, UI metadata, source locations, or resource URLs are top-level expectation
fields. Descriptor semantics stay canonical, including nested descriptors outside
this bounded form slice. Admission uses VIR's `interfaceSignatureKey`: canonical
type shape and effect, independent of JSON key order. This is not arbitrary JSON
metadata equality. Nested constructor names, canonical constructor `jsName`,
ordered fields, layout and other ABI descriptor fields remain intact; excluding
top-level argument display names does not strip names from nested descriptors.

For this slice, pure homogeneous String/String, Nat/Nat, Bool/Bool, and
UInt64/UInt64 use primitive `type`/`interfaceTag` descriptors: String/3, Nat/0,
Bool/2, UInt64/7. Multiline is String presentation only. Expectations come from
independent Lean classification, never from the producer manifest.

Concrete Bool expectation:

```json
{"args":[{"type":"Bool","interfaceTag":2}],"result":{"type":"Bool","interfaceTag":2},"effect":"pure"}
```

Concrete UInt64 expectation:

```json
{"args":[{"type":"UInt64","interfaceTag":7}],"result":{"type":"UInt64","interfaceTag":7},"effect":"pure"}
```

The native owner's explicit contract in
`VIR-PR223-DIAGNOSTICS-SIGNATURE-CLAIM-20261008-001` and its concrete
`ClassifiedSignature.toExpectedSignatureJson` implementation match that proposal.
The consumer directly accepted that offered contract before form implementation
in queue message `01a11b30-ae3c-73b2-89ff-6e3d1b4a6676`;
the native encoder can be qualified against it. This agreement does not select
PR223 or a successor runtime in the main checkout.

## Bounded consumer checkpoint and isolated codec successor

The concrete forms are complete locally on bda/e415: `lake build` passed 866 jobs,
and `lake test -- --mutations` passed 85 checks, including the 29 typed checks.
The combined local demo separately passed 15 checks. The preserved source patch
is `_out/typed-forms-source.patch`, SHA256
`09293919b0cbfecd9a2458fa8f73b881da79f857a26961d35248ff45e8f4ffd0`.
This snapshot includes the live Blog, anchors and documentation work.

The explicit `VIR-PR223-CODEC-LOCAL-CONSUMER-HANDOFF-20261008-001` and WORKBOARD
selection supersede the helper deferral only for an isolated local successor,
after exact producer CI. Producer `696cc49328906185d6d0284835da7b7d89a97dc5`
retains compatibility 3 and the same e415 lock. The successor is
`_out/codec-successor`, branch `gate/codec-696-e415`, copied and verified against
all 178 current source/evidence inputs before its changes. Only its VIR source
pin and agreed compiler imports/helper call change for codec adoption.
The main checkout keeps bda/e415. No alias/config/v4 composition, hosted
deployment, public consumer push, merge or cleanup is selected.

Contract/ownership checkpoint was sent directly to the native owner in queue
message `01a11b85-73d7-7952-923b-620ee708cb70`. There is no source overlap.
The codec preserves ordered arguments, including zero or multiple arguments,
and canonical `pure`, `runtime`, `io`, `dom`, or `react` effects. Our forms accept
one pure homogeneous scalar argument/result; they do not narrow the VIR codec.
Erased implementation slots are excluded from expected value arguments. Bool
inputs cross as actual booleans; UInt64 inputs cross as BigInt within unsigned
64-bit bounds; multiline changes String presentation only.

Isolated helper acceptance passed: `lake build` (866 jobs), then
`lake test -- --mutations --output _out/codec-acceptance` (85 checks, including
29 typed checks). After mutation restoration, only the isolated lakefile,
manifest and Callable migration inputs differ from the copied source snapshot.
All three genre publication plans exactly match the bda/e415 typed checkpoint;
all published resource members were checked against their SHA256 identities.
The isolated gate reused cached dependency builds; no clean consumer build or
hosted acceptance is claimed. Exact identities and checks are retained in
the historical `codec-successor.json` (retained in Git at `23f449e`).

The bounded read-only review found no implementation blocker. Its stale Boolean
rejection example in `docs/troubleshooting.md` is corrected in the preserved main
work and isolated successor to the tested `signedIdentity : Int → Int` example.
Both displayed diagnostic lines match the retained negative acceptance logs.
The successor's follow-up is documentation only; the 85-check/29-typed acceptance
at `e4ea185` remains the implementation evidence, without a broad rerun. The
current clean successor head and documentation verification are recorded in
`codec-successor.json` separately from that tested head.
