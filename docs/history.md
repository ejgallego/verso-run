# Origin and design provenance

The first runnable-Manual prototype lived in Verso's `experiments/lean-run` on
`feat/lean-run`. Its eight development commits were extracted from Verso commit
`06860e5e`. The extension was published as `verso-vir`, briefly named `verso-lab`,
and renamed to `verso-run`. `verso-lab` is reserved for broader source-editor work.
The public `VersoLeanRun` name was retained.

## Decisions that shaped the extension

**Retain elaborated source.** Run blocks reuse Verso's command elaboration and
highlighted source. Their declarations compile in the document environment;
imported anchors reuse Verso's checked `ExternalCode` path. This keeps the shown
implementation connected to execution and preserves each genre's native source
rendering, links and static fallback.

**Derive contracts from the compiler.** Publication supplies expected callable
signatures independently of the downloaded executable. VIR validates that
contract when creating the program. Input controls and presentation kinds do not
reconstruct an ABI in JavaScript. Module-owned resource facets and carriers keep
preparation before embedding and publication outside elaboration.

**Keep computation in Lean.** The stack calculator and stepper share one parser
and evaluator. Life supplies a pure transition and SVG view. `Sequence` describes
a finite recording; `Automaton` describes a live transition system. Shared frames
and observation helpers connect their presentations. `trace` uses Lean's
`List.scanl`, sequence mapping uses `Functor`/`LawfulFunctor`, and text views use
`ToString`. These helpers belong to verso-run; they are not Illuminate's animation
framework. Illuminate's drawing-command/SVG path is qualified separately.

**Make execution lifetime explicit.** Each placement owns a dedicated worker.
Stop can interrupt synchronous Wasm execution. Live playback keeps only the
current model and waits for execution and presentation before advancing again.
Finite selection uses recorded states. Run and Play are explicit reader actions;
Restart, hiding and navigation have documented lifetime rules.

**Isolate generated markup.** Lean renders Html; a separate Lean/VIR DOM presenter
puts it in a sandboxed document. The parent page does not insert returned markup
into its own DOM. Qualification covers the exercised policy and bindings, with
browser and accessibility limits recorded separately.

## Development records

[PRs](https://github.com/ejgallego/verso-run/pulls?q=is%3Apr) and
[Git history](https://github.com/ejgallego/verso-run/commits/main/) contain the
detailed change record. The [views consolidation](https://github.com/ejgallego/verso-run/pull/11)
links its earlier implementation slices and review fixes. Exact validation
results belong to the associated CI run or retained evidence, rather than this
provenance page. Generated prototype reports and captures remain in Git history
at `23f449e` and describe their recorded revisions.

For current behavior use the [authoring guide](authoring.md), for architecture
use [internals](internals.md), and for qualification use [validation](validation.md).
Future directions live in the [roadmap](../ROADMAP.md).
