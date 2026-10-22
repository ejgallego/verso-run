# Illuminate execution gates

The demo qualifies Illuminate's drawing-command/SVG path. The
[dependency table](../docs/internals.md#pinned-dependencies) records the exact
Illuminate, VIR, and runtime revisions used by the project.

## Drawing commands and SVG

`LeanRunGate.diagram` bounds the reader's count to 1–8, computes coordinates and
a view box, constructs paths, transforms, colors, and text as
`Array (DrawCmd Empty)`, and calls `Svg.render`. Its result is structured Lean
HTML, serialized by the compiled presenter into a sandboxed document. Each
preview isolates its SVG identifiers from the surrounding document.

Lean computes the edited result in a dedicated Wasm worker. Acceptance compares
its SVG markup with native Lean, then checks labels, filled and stroked paths,
and view boxes in the browser. It covers valid counts, malformed and out-of-range
input, repeated runs, source fallback, and relocated static output.

## Scope of qualification

General `Diagram.compile` and `Diagram.renderDiagram` workflows remain
unqualified. The drawing-command demo does not exercise their complete layout,
arrow, hashing, or rendering behavior.

Earlier negative fixtures expected `Float.toBits`, `Float.atan`, and `Float.asin`
to be unavailable. The selected VIR now provides those operations, so those
failure expectations have been retired. Their availability alone does not
establish native/browser agreement for general diagram rendering.

Unsupported dependency coverage uses `Lean.Expr.dbgToString`: resource packaging
must reject its executable closure with declaration provenance. The mutation
campaign also checks that introducing this unavailable operation into an
accepted entry fails without overwriting the previous publication.
