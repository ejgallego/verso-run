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

The selected dependencies are public VIR `fb5af647` and compatible Slides `35b5d14b`,
with unchanged runtime `e415…`. The compiler-owned expectation codec and bare Module
resource prerequisites preserve all six unique packs and 267 emitted member hashes.
Publication loading cancellation is qualified before any response, with fresh-fetch
retry and concurrent placements. The browser test also checks actual public promise
settlement; runtime-Wasm cancellation remains a separate test.

The combined-site gate covers typed and inline examples and compares all four shared
JavaScript files in every genre. `verso-run-build.json` records the generator's exact
source/dependency/runtime identities; a hosted run requires the deployed revision and
a clean build using `tests/pages-smoke.py --revision COMMIT`.

## Evidence to consult

| Record | Scope |
| --- | --- |
| [Landed public adoption](../evidence/public-adoption.json) | Local `cb016c4` checkpoint: 89 checks, 7 focused lifecycle checks, 31 combined-site checks, identical executable assets; final cold Git/hosted gates belong to the exact main CI/deployment |
| [Inline genres](../evidence/inline-genres-results.json) | 86 checks, including 26 inline and 29 typed; Page/Post/Slides definitions, retained scopes, native source and actual workers |
| [Entry-selected interface](../evidence/entry-interface-results.json) | 85 checks, including 29 typed; annotation-free entries, type-derived output, and document-owned scalar/Html adapters |
| [Typed form claim](../evidence/typed-forms-claim.md) | Source/base ownership and exact type-only schema agreement; bda/e415 retained |
| [Typed forms](../evidence/typed-forms-results.json) | 29 codec/native/browser checks across all three genres and root/nested hosting |
| [Typed regression](../evidence/typed-regression.json) | 85-check native/browser/mutation campaign, local source only |
| [Typed combined site](../evidence/typed-combined-site.json) | Local combined inventories, links, viewports, and existing native calls |
| [Slides results](../evidence/slides-results.json) | 20 native/Reveal/browser checks, including mobile scrolling and restored controls |
| [Slides regression](../evidence/slides-regression.json) | 81-check Manual/Blog/Slides native/browser/mutation campaign |
| [Three-genre site](../evidence/three-genre-local-site.json) | Landing links, viewports, inventories, and 12 native worker comparisons |
| [Blog results](../evidence/blog-results.json) | 16 native/browser Page/Post checks at root and nested prefixes |
| [Blog regression](../evidence/blog-regression.json) | 80-check Manual/Blog native/browser/mutation campaign |
| [Combined local site](../evidence/blog-local-site.json) | Landing links, viewport checks, and eight Manual/Blog native worker comparisons |
| [Public-pair starter](../evidence/public-pair-starter.json) | 11-check cold public Git acquisition/build and native/browser starter campaign |
| [Public-pair Pages](../evidence/public-pair-pages.json) | Actual hosted/native agreement, publication equality, and runtime MIME responses |
| [Public-pair worker](../evidence/public-pair-worker.json) | Full-name calls, raw BigInt type, dispose and fresh creation |
| [Public-pair results](../evidence/public-pair-results.json) | 79-check v3 resource, full-name, BigInt, native/browser/mutation campaign |
| [Anchor results](../evidence/anchors-results.json) | 77-check shared-core and anchored Manual native/browser/mutation campaign |
| [Diagnostics results](../evidence/diagnostics-results.json) | Earlier 65-check native/browser/mutation campaign |
| [Validation log](../evidence/validation.txt) | Dated campaigns, exact identities, commands and limitations |
| [Prototype results](../evidence/results.json) | The earlier 55-check demo campaign |
| [Starter results](../evidence/starter-results.json) | The published-dependency starter and its 11 checks |
| [Worker gate](../evidence/worker-gate.json) | Public VIR create/call/dispose/recreate checks |
| [Illuminate gates](../evidence/illuminate-gates.md) | Qualified SVG path and missing float-provider fixtures |
| [Design review](../evidence/design-results.json) | Earlier interaction and viewport campaign |

Earlier evidence is retained as history; it is not an assertion that every file
was regenerated at the current commit. A local test run writes current logs and
`results.json` under its selected output directory. The
[CI runs](https://github.com/ejgallego/verso-run/actions/workflows/ci.yml) are the
record for fresh-checkout build/test and deployment results.

## Visual review and limits

The prototype was inspected at 1280px, 390px and 320px widths, including expanded
source, keyboard focus/submission, long natural-number output, search, and
JavaScript-disabled pages. Representative captures:

- [Diagram on desktop](../evidence/illuminate-desktop-4.png) and
  [mobile](../evidence/illuminate-mobile-4.png).
- [Calculator](../evidence/calculator-desktop.png) and
  [expanded source](../evidence/calculator-desktop-source.png).
- [Typed HTML](../evidence/html-desktop.png).
- [Blog post on desktop](../evidence/blog-desktop.png) and
  [mobile](../evidence/blog-mobile.png); [landing page](../evidence/landing-desktop.png)
  and its [mobile layout](../evidence/landing-mobile.png).
- [Slides on desktop](../evidence/slides-desktop.png) and
  [mobile](../evidence/slides-mobile.png).
- [Three-genre landing](../evidence/three-genre-landing-desktop.png) and
  its [mobile layout](../evidence/three-genre-landing-mobile.png).
- [Typed controls on desktop](../evidence/typed-forms-desktop.png) and
  [mobile](../evidence/typed-forms-mobile.png).

Browser execution is qualified here in Chromium. Firefox, Safari, physical
mobile devices, and assistive-technology audits remain outside this evidence.
The cached-page handler is tested with a persisted `PageTransitionEvent`;
actual browser back-cache restoration remains unqualified.

General Illuminate diagram compilation is also unqualified. Only the documented
drawing-command/SVG path is supported by this demo. See [hosting](hosting.md) for
the actual hosted runtime qualification.
