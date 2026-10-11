# Validation and retained evidence

The main acceptance suite exercises the real native generator and the real
Chromium worker. It compares edited-input results with a native Lean oracle,
rather than treating successful loading as proof that an example works.

## What the suite checks

- Closed form metadata round-trips and rejection of unsupported combinations;
  native wire tags checked against browser codecs and the generated HTML serializer.
- Idempotent, document-scoped publication bindings with deterministic output;
  conflicting signatures, manifests, and callables reject in either order with
  both source locations, before publication writes.
- All generated browser descriptions contain exactly six reader/invocation fields
  and resolve published bindings in both Manual HTML layouts, Blog Page/Post, and
  Slides. Native genre collectors retain producer ownership and source locations.
- Entry-selected exports without author annotations, type-derived result display,
  unannotated imported producers and document-owned scalar/HTML wrappers.
- Text, Unicode, exact natural numbers, calculator traces and bounds, typed
  HTML escaping and isolation, and Illuminate SVG markup and geometry.
- Independent forms, repeated placements, real Stop, pending-load cancellation,
  stale-result suppression, explicit retry, and preview cleanup.
- Author diagnostics, source locations, unsupported interfaces and dependency
  closures, compiler signatures, and rejection before invocation.
- Embedded native-only generation, root and nested copied sites, both HTML
  layouts, no-JavaScript source, and TeX output.
- Source/helper invalidation, restored identity, missing/duplicate stock
  registration and logical-ID conflicts, and relocated carrier source/build roots.
- Rejected replacements and wrong producer registrations after a successful build,
  including preservation of the last accepted publication.
- Imported scalar anchors, semantic entry membership, checked source bodies,
  native definition links, and duplicate/unclosed/stale-anchor rebuild rejection.
- Inline Page/Post/Slides definitions, retained namespaces and repeated selection,
  scalar/Html authoring, native source and source-located rejection diagnostics.
- Blog Page/Post typed collection, native-only publication, malformed metadata,
  nested asset URLs, automatic typed HTML, no-JavaScript source, and the combined landing.
- Blog draft policy for root collection/planning and nested native generation:
  hidden drafts require no bundle; shown drafts require registration before writes.
- Slides typed collection, one formatter/Run runtime inventory, asset collisions
  before output, native fragments, visibility cancellation, keyboard submission,
  pending-load guards, and readable static source.
- Typed sequences, automatic scalar adapters, independently classified DOM
  presenters, every native frame, exact stacks and errors, previous/next and
  scrubbing, independent placements, stale listeners, and presenter-load Stop.
- Game of Life rules and parsing, exact native generations, SVG views, edited seeds,
  and invalid-input recovery.
- Raw Html/sequence scripts, event handlers, external embedded resources, top
  navigation and form submission under the shared sandbox document policy.

The [contributor guide](../CONTRIBUTING.md) gives commands and explains mutation
test isolation. CI also cold-builds the independently pinned
[author starter](../examples/manual-starter/README.md) without Lake artifact-cache
reuse and runs its 11 checks. The starter acquires public extension `f2a1491` and
the selected runtime through its complete Git manifest, without local seeds.

The selected dependencies are VIR PR #229 at `957854b9` and compatible Slides `6e514cd4`,
with VIR's locked runtime `6cddc4b8…`. Resource dependencies and includes now name
program modules explicitly. The independently pinned starter tests the same Lean 4.35.0-rc4 and
module-owned-assets API from the published extension revision.
Publication loading cancellation is qualified before any response, with fresh-fetch
retry and concurrent placements. The browser test also checks actual public promise
settlement; runtime-Wasm cancellation remains a separate test.

The combined-site gate covers typed, inline, sequence and Life examples and compares all six shared
JavaScript files in every genre. `verso-run-build.json` records the generator's exact
source/dependency/runtime identities; a hosted run requires the deployed revision and
a clean build using `tests/pages-smoke.py --revision COMMIT`.

## Current qualification

The consolidated campaign exercises the sequence and typed-rendering libraries,
the stack stepper, and Game of Life together with binding conflict checks and
browser metadata projection. Command logs and results are written to the selected output directory; CI
artifacts identify the exact source revision that passed the full gates.

All 20 input/presentation forms have independently classified expectations.
Sequence frames use typed VIR transport with exact integer values and a combined
65,536 UTF-16 code unit output budget. The real held-module tests cover deadline,
Stop, retry of the same pending import and observed late rejection. Raw-markup
checks use the actual compiled Html, sequence, and automaton presenters, rather than relying
only on interpolated-text escaping.

Life's known-pattern tests check still lifes, oscillation, extinction, glider
translation and dead boundaries. Browser tests compare exercised generations with
native Lean across all genres at root and nested paths. The dense-board case
checks the output budget; invalid seeds remain Lean errors with explicit recovery.

Run `lake build`, followed by `lake test -- --mutations --output _out/acceptance`.
The suite writes command logs and `results.json` to that ignored directory.
CI uploads `_out/` as an artifact; consult the
[CI runs](https://github.com/ejgallego/verso-run/actions/workflows/ci.yml) for
fresh-checkout validation and deployment results.

Earlier per-PR counts and qualification checkpoints are linked from
[project history](history.md#lean-authored-views-and-pre-merge-consolidation). They
describe their own immutable revisions, not this integration automatically.

Generated JSON reports, logs, and prototype screenshots have been removed from
the source tree. Earlier records remain in Git history at `23f449e`;
they describe their own revisions, not the current checkout. The written
[Illuminate qualification](../evidence/illuminate-gates.md) and
[typed-form review](../evidence/typed-forms-claim.md) retain their scope and limits.
The [README illustration](images/illuminate-desktop-4.png) is documentation artwork.

## Qualification limits

Browser execution is qualified in Chromium. Firefox, Safari, physical mobile
devices, and assistive-technology audits remain outside this evidence.
The cached-page handler is tested with a persisted `PageTransitionEvent`;
actual browser back-cache restoration remains unqualified.

General Illuminate diagram compilation is also unqualified. Only the documented
drawing-command/SVG path is supported by this demo.

The live Life gate compares native and worker frames beyond generations 12 and
128, exercises Play/Pause/Step and Stop/restart, and checks that updating a frame
keeps the DOM size constant. Native known-pattern tests remain independent of
that agreement oracle. Scheduler tests hold transitions open to qualify
backpressure, pause, reset generations, and failure recovery.

Live preview tests hold a staged iframe load while asserting that the previous
visible document and label remain unchanged. Stop must discard that pending swap.
Seed drafts are checked during active playback, including explicit Restart and
resumption with the new model. Short showcase source is visible by default;
Life includes checked anchors for its transition, state, and SVG view.
