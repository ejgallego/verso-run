# Contributing to verso-run

Start with the [README](README.md) to run the demo and the
[author starter](examples/manual-starter/README.md) to build a document of your own.
Repository-specific constraints are in [AGENTS.md](AGENTS.md).

## Worktrees and pull requests

Use one task branch and one worktree under `.worktree/` for new code work. From the
main checkout, start a task with a descriptive name in place of `example`:

```sh
git fetch origin
git worktree add -b feat/example .worktree/example origin/main
cd .worktree/example
```

Keep each worktree's build and generated outputs independent. Existing working
changes and older `.worktrees/` checkouts can remain where they are until their
tasks are complete. Do not reset the main checkout or move another task's work.

Keep a PR focused on one change. Before submission, inspect the diff and working
tree, run the validation below sequentially for code changes, and use conventional
commit subjects. Documentation-only changes need a diff and link review.

Push the task branch and open a PR against `main`:

```sh
git push -u origin feat/example
gh pr create --base main --head feat/example --title "feat: describe the change" \
  --body-file /tmp/verso-run-example-pr.md
```

Write the description file first: explain the resulting behavior, relevant
validation and remaining limits. Include screenshots or reproduction instructions
for visible changes. Use `--draft` if implementation or validation is incomplete.
Report the PR URL and address review on the same branch.

Merge after the maintainer requests or approves it and CI passes on the current
head. Record the reviewed head from `gh pr view NUMBER --json headRefOid`, check
`gh pr checks NUMBER`, and merge that exact revision:

```sh
gh pr merge NUMBER --squash --match-head-commit REVIEWED_HEAD_SHA
```

Squash is the default. If the head changes, check the new diff and CI before
merging. Do not bypass checks. Merging to `main` triggers the demo's Pages workflow;
report the merge and deployment status separately.

After GitHub confirms the PR is merged, retain any evidence referenced by the PR
outside disposable worktree outputs. From the main checkout, inspect and remove
only that task's clean worktree:

```sh
git -C .worktree/example status --short
git worktree remove .worktree/example
git push origin --delete feat/example
git branch -d feat/example
```

Skip remote deletion if GitHub already deleted the branch. A squash merge may
make `git branch -d` refuse because the original commits are not ancestors of
`main`. Only after confirming that the PR for this exact branch/head is merged
and all work is preserved, use `git branch -D feat/example`. Never force-remove a
dirty worktree or clean unrelated directories. Fetch the new `main`; fast-forward
the main checkout only when its working tree is clean.

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

`lake test` keeps uv and Python caches in the checkout’s ignored `.cache/`
directory, avoiding shared-cache write permissions. Set `UV_CACHE_DIR` or
`UV_PYTHON_INSTALL_DIR` to override those locations. For direct browser commands,
use `UV_CACHE_DIR="$PWD/.cache/uv" uv run …`.

The suite builds the native oracle and generator, checks author diagnostics,
compares real worker calls to native Lean, and exercises Manual's two HTML layouts
and TeX, plus Blog Page/Post and Slides. Mutation checks temporarily edit the chapter, helper, and Lake
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

## Repository layout

| Path | Purpose |
| --- | --- |
| `src/` | Lean block elaboration, HTML rendering, and publication |
| `web/` | Input validation, UI state, worker ownership, and asynchronous invocation |
| `demo/chapters/` | Manual, Blog, and Slides documents and their Lean functions |
| `demo/generators/` | Native generators for the three demo genres |
| `demo/resources/` | Embedded program carriers; `lakefile.lean` owns module registration |
| `examples/manual-starter/` | Copyable independent author project |
| `tests/` | Native/browser acceptance and negative author fixtures |
| `docs/`, `evidence/` | Guides, documentation artwork, and written qualification limits |

`demo/generators/DemoMain.lean` builds the Manual; `demo/generators/BlogMain.lean` builds the Blog site.
`demo/generators/SlidesMain.lean` builds the deck. `scripts/build-demo-site.py` combines them with a landing page.
`tests/native/OracleMain.lean` and `tests/native/BlogOracleMain.lean` supply native reference results.
`tests/native/PublicationMain.lean` checks resource registration with real bundles.
Generated Lake, Beam, VIR, browser, and site outputs stay out of Git.
Generated qualification reports and prototype captures belong in `_out/` or CI
artifacts; their earlier versions remain in Git history at `23f449e`. Keep only
illustrations used by documentation in `docs/images/`.

Within `src/VersoLeanRun/`, `Model`, `Callable`, `Anchored`, `Render`,
`Collect`, and `Publication` hold the common machinery. `Manual` and `Publish`
adapt it to Manual elaboration, native source blocks, and generator output.
`VersoLeanRun` remains the compatibility facade. `Blog` and `Blog.Publish`
adapt the same core to Page/Post. `Slides` and `Slides.Publish` retain native code
and compose with the stock Slides asset plan. See the [genre review](docs/multi-genre.md).

`Sequence` holds pure author states and typed frame transport; `Preview` owns the
shared sandbox document policy. `VersoLeanRunPresenter` implements browser DOM
presentation through VIR. Its separate resource carrier keeps browser-only
definitions out of native generator compilation. `web/presenter.js` owns loading,
cancellation and disposal for both Html and sequence views.

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
