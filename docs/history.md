# Project history

This repository extracts the prototype previously developed in
`experiments/lean-run` on Verso's local `feat/lean-run` branch. Its eight
development commits are preserved with paths moved to the repository root.
The extraction source is Verso commit `06860e5e`; original evidence is retained.
The Verso dependency isolates the one-line highlighting hook from that prototype.

Use `VersoLeanRun` and `VersoLeanRun.Publish` as the library imports. The Lean
package is named `verso_run`; the existing module and executable names are retained.
Library support lives under `src/`, browser support under `web/`, and demo
code under `demo/chapters/` and `resources/`. Illuminate code belongs to the examples.

See [LICENSE](../LICENSE) for the Apache-2.0 license and [AGENTS.md](../AGENTS.md) for
contributor notes. GitHub CI builds from the exact dependency pins and runs all
acceptance/mutation checks, retaining the generated site and test evidence.

The project was initially published as `verso-vir`, briefly named
`verso-lab`, and renamed to `verso-run`. The name `verso-lab` is reserved
for a future project with editor support.
The public `VersoLeanRun` module API and existing executable names are retained.
