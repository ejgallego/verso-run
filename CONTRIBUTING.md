# Contributing to verso-run

Start with the [README](README.md) to run the demo and the
[author starter](examples/manual-starter/README.md) to build a document of your own.
Repository-specific constraints are in [AGENTS.md](AGENTS.md).

## Build and test

Install [elan](https://github.com/leanprover/elan), [uv](https://docs.astral.sh/uv/),
and Chromium. Tests use an installed `google-chrome` if available; otherwise:

```sh
uv run --with playwright playwright install chromium
```

Run these sequentially from the repository root:

```sh
lake build
lake test -- --mutations --output _out/acceptance
```

The suite builds the native oracle and generator, checks author diagnostics,
compares real worker calls to native Lean, and exercises both HTML layouts and
TeX. Mutation checks temporarily edit the chapter, helper, recipe, and Lake
layout, then restore them in `finally`. Avoid concurrent builds or edits to
those files. Check the working tree after an interrupted test run.

Individual command logs and `results.json` are written to the selected output
directory. The default is `/tmp/verso-lean-run-acceptance` if `--output` is omitted.
Existing qualification reports and screenshots are described in
[validation](docs/validation.md).

The starter has an independent cold Git-dependency check:

```sh
uv run --with playwright python tests/starter.py
```

It copies the starter outside the repository, builds its pinned published
dependency, and runs its text and HTML examples at root and nested URLs. It
qualifies that published revision; the main acceptance suite checks your working
tree changes. CI runs both before deploying the demo.

A smaller public VIR worker gate is also available:

```sh
lake exe lean-run-gate /tmp/verso-lean-run-gate-site
uv run --with playwright python tests/worker-gate.py
```

## Repository layout

| Path | Purpose |
| --- | --- |
| `support/` | Lean block elaboration, HTML rendering, and publication |
| `web/` | Input validation, browser UI, worker ownership, and invocation |
| `gates/` | The demo chapter, functions, and helper module |
| `resources/`, `vir-resources/` | Embedded demo bundle and its recipe |
| `examples/manual-starter/` | Copyable independent author project |
| `tests/` | Native/browser acceptance and negative author fixtures |
| `docs/`, `evidence/` | Guides, qualification records, and screenshots |

`DemoMain.lean` builds the site; `OracleMain.lean` supplies the native reference
results. `PublicationMain.lean` checks resource registration with real bundles.
Generated Lake, Beam, VIR, browser, and site outputs stay out of Git.

Within `support/VersoLeanRun/`, `Model`, `Callable`, `Anchored`, `Render`,
`Collect`, and `Publication` hold the common machinery. `Manual` and `Publish`
adapt it to Manual elaboration, native source blocks, and generator output.
`VersoLeanRun` remains the compatibility facade. See the
[genre review](docs/multi-genre.md) for the planned Blog and Slides adapters.

## Changing the code

Keep `VersoLeanRun` and `VersoLeanRun.Publish` as the public imports. Keep document
elaboration, resource publication, worker invocation, and rendering separate.
The [integration guide](docs/internals.md) explains the dependency graph.

Reuse VIR's interface classification and resource APIs. Preserve original
classifier reasons and structured worker causes when improving diagnostics.
Add negative cases to `tests/negative/cases.json`; cases can assert the
declaration, type, cause, remedy, and source line rather than an entire message.

Use conventional commit subjects and explain behavior and relevant validation.
Keep exact Lean, Verso, VIR, and Illuminate pins unless updating a dependency is
the selected task. A new VIR runtime requires its matching public source and
artifact, plus consumer qualification; local producer packs are not a substitute.

Compiler scheduling, native precompilation, Verso core upstreaming, and wider
browser qualification retain their deferred status in [the roadmap](ROADMAP.md).
