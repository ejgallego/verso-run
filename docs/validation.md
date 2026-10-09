# Validation and retained evidence

The main acceptance suite exercises the real native generator and the real
Chromium worker. It compares edited-input results with a native Lean oracle,
rather than treating successful loading as proof that an example works.

## What the suite checks

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
- Slides typed collection, one formatter/Run runtime inventory, asset collisions
  before output, native fragments, visibility cancellation, keyboard submission,
  pending-load guards, and readable static source.

The [contributor guide](../CONTRIBUTING.md) gives commands and explains mutation
test isolation. CI also cold-builds the independently pinned
[author starter](../examples/manual-starter/README.md) without Lake artifact-cache
reuse and runs its 11 checks. The starter acquires public extension `cb016c4` and
the selected runtime through its complete Git manifest, without local seeds.

The selected dependencies are VIR PR #229 at `957854b9` and compatible Slides `daa96fee`,
with VIR's locked runtime `6cddc4b8…`. Resource dependencies and includes now name
program modules explicitly. The independently pinned starter continues to test
its published Lean 4.34.0 dependency and older resource API.
Publication loading cancellation is qualified before any response, with fresh-fetch
retry and concurrent placements. The browser test also checks actual public promise
settlement; runtime-Wasm cancellation remains a separate test.

The combined-site gate covers typed and inline examples and compares all four shared
JavaScript files in every genre. `verso-run-build.json` records the generator's exact
source/dependency/runtime identities; a hosted run requires the deployed revision and
a clean build using `tests/pages-smoke.py --revision COMMIT`.

## Current results and historical evidence

Run `lake build`, followed by `lake test -- --mutations --output _out/acceptance`.
The suite writes command logs and `results.json` to that ignored directory.
CI uploads `_out/` as an artifact; consult the
[CI runs](https://github.com/ejgallego/verso-run/actions/workflows/ci.yml) for
fresh-checkout validation and deployment results.

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
