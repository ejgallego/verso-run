# Next steps

The current extension supports entry-selected pure scalar and typed HTML calls
in Manual, Blog Page/Post, and Slides, with inline definitions or checked source
anchors. The [internals](docs/internals.md) describe the implementation and exact
pins; [history](docs/history.md) records how these features arrived.

## Author and runtime diagnostics

Improve dependency-closure diagnostics where a supported callable reaches an
unavailable runtime operation. Preserve VIR's original classifier reason,
declaration/type context, and actionable wrapper guidance. Keep author errors,
reader input errors, and resource/worker failures distinct.

Future interface or runtime changes require a matched source/runtime pair and
consumer qualification. Retain independent expected signatures, exact integer
boundaries, explicit retry, independent workers, and real Stop.

## Native build performance

Measure cold/warm builds and author iteration before selecting native
precompilation. VIR's compiler-library separation is already used, but consumer
precompilation remains deferred. Preserve ordinary Git acquisition and the
locked browser runtime. Compiler scheduling is a separate change: retain
`compiler.postponeCompile false` until it is deliberately reviewed and qualified.

## Verso integration

Review upstream integration of the public Manual highlighting helper and the
shared command-elaboration hooks used by the genre adapters. Slides updates must
retain native fragments, source rendering, asset collision checks, and worker
cancellation on navigation. Keep publication and invocation outside document
elaboration.

## Browser and accessibility qualification

Qualify Firefox, Safari, physical mobile devices, accessibility, and actual
browser back-cache restoration separately. Current checks cover Chromium and
synthetic persisted-page lifecycle events; see [validation](docs/validation.md).

General Illuminate diagrams require the missing float-provider work recorded in
[evidence/illuminate-gates.md](evidence/illuminate-gates.md). The current demo
qualifies the drawing-command/SVG path.

## Source editing

Readers currently edit function inputs. Lean source editing and the broader
`verso-lab` project remain separate work; they require their own compiler,
interaction, and lifecycle design.
