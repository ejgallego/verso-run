# Illuminate execution gates

The diagram example uses unchanged Illuminate source at
`a1a61c9678da010e958ed24cdfa6f635b85f172a` (Lean 4.34.0), matching the
Verso release dependency. VIR is PR #217 snapshot
`1ed079ca2ab8306ae877ed4920f7d55d392365f8`. Its runtime bundle remains
`832ab095ad79df0f10f538bcf71272731bb74b90df44f965dac2f086c222897d`.
The earlier local Illuminate checkout at `006dc1d1` also built under 4.34,
but the demo uses the matching release revision.

## Accepted drawing-command path

`LeanRunGate.diagram` parses and bounds the count (1–8), computes coordinates
and a view box, constructs `PathData.circle`, line paths, matrix transforms,
colors, and text as `Array (DrawCmd Empty)`, and calls `Svg.render`.
It returns typed Verso HTML; its generated `diagram.leanRunHtml` wrapper uses
Verso's serializer at the scalar VIR boundary. The SVG renderer receives a
fixed frame-local prefix. Each SVG preview lives in its own sandboxed frame.

No Illuminate or VIR source patches, native-provider profiles, JavaScript
geometry implementation, or build-time SVG lookup are used. The reader's
edited count is executed by the existing dedicated Wasm worker. The browser
checks compare the markup to native Lean, then inspect actual SVG labels,
filled/stroked paths and view boxes. They cover counts 1, 4, 8, 2 and additional
reruns, malformed/out-of-range counts, source fallback, and copied HTTP output.

## General diagram APIs remain unqualified

From `experiments/lean-run`, the following committed fixtures must fail on
this pinned runtime:

```sh
lake env lean tests/negative/IlluminateHashing.lean
lake env lean tests/negative/IlluminateCompile.lean
lake env lean tests/negative/IlluminateAsin.lean
```

- `Diagram.renderDiagram` hashes diagram geometry for SVG ID prefixes.
  Its compiled dependency closure reaches unsupported `Float.toBits`.
- Even a circle passed to `Diagram.compile` retains the general compiler's
  arrow branches. The first reported unsupported operation is `Float.atan`
  through `ArrowDraw.minHalfAngle`.
- That helper also uses `Float.asin`; the third fixture isolates the missing
  native provider directly.

The native extern catalog is unchanged between the original PR #217 pin
`ff65dc8823e3c6be1ff5c549d89c3683c18e7fd9` and this snapshot. These failures
were reproduced during author validation and remain part of acceptance.
They are evidence for a VIR runtime/provider follow-up, not a claim that the
whole Illuminate diagram API runs in this demo. `Float.toBits` has a Lean
reference body, so VIR's existing explicit extern-fallback mechanism is
another candidate to investigate for that particular operation; it was not
needed or qualified for this example. The two inverse-trigonometric operations
are opaque and need native support for the general diagram compiler.
