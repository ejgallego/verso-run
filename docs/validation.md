# Validation and retained evidence

The main acceptance suite exercises the real native generator and the real
Chromium worker. It compares edited-input results with a native Lean oracle,
rather than treating successful loading as proof that an example works.

## What the suite checks

- Text, Unicode, exact natural numbers, calculator traces and bounds, typed
  HTML escaping and isolation, and Illuminate SVG markup and geometry.
- Independent forms, repeated placements, real Stop, pending-load cancellation,
  stale-result suppression, explicit retry, and preview cleanup.
- Author diagnostics, source locations, unsupported interfaces and dependency
  closures, compiler signatures, and rejection before invocation.
- Embedded native-only generation, root and nested copied sites, both HTML
  layouts, no-JavaScript source, and TeX output.
- Source/helper invalidation, restored identity, missing/duplicate/ambiguous
  registration, and relocated carrier source/build roots.
- Rejected replacements and wrong recipe contracts after a successful build,
  including preservation of the last accepted publication.

The [contributor guide](../CONTRIBUTING.md) gives commands and explains mutation
test isolation. CI also cold-builds the independently pinned
[author starter](../examples/manual-starter/README.md) and runs its 11 checks.

## Evidence to consult

| Record | Scope |
| --- | --- |
| [Diagnostics results](../evidence/diagnostics-results.json) | Current 65-check native/browser/mutation campaign |
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

Browser execution is qualified here in Chromium. Firefox, Safari, physical
mobile devices, and assistive-technology audits remain outside this evidence.
The cached-page handler is tested with a persisted `PageTransitionEvent`;
actual browser back-cache restoration remains unqualified.

General Illuminate diagram compilation is also unqualified. Only the documented
drawing-command/SVG path is supported by this demo. See [hosting](hosting.md) for
the pending GitHub Pages MIME/runtime integration gate.
