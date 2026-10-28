# Contributing to verso-run

Start with the [README](README.md) to run the demo and the
[author starter](examples/manual-starter/README.md) to build a document of your own.
Repository-specific constraints are in [AGENTS.md](AGENTS.md).

## Development lanes

Group work by its main purpose. A lane helps people find related tasks and agree
on dependencies. Tasks have short-lived branches, and lanes can touch shared files.

| Lane | Work |
| --- | --- |
| Library and runtime | Lean APIs, elaboration, genre adapters, publication, worker and presenter lifetimes, dependency integration |
| Authoring and documentation | Setup guides, API explanations, checked examples, reference presentation, contributor instructions |
| Examples and presentation | Demo computations, gallery, walkthroughs, slide composition, and visual design |

Each task includes its own relevant tests and documentation. Complete the required
checks before marking it ready for review.

For a batch of related work, name one integration owner to keep the landing order,
reviewed revisions, preview, and publication status clear. That person can also
implement a task; merges still require maintainer approval and current CI.

### Thread titles

Name each development thread after its lane and the open PRs it owns:
`<lane> · verso-run · #<PR>, #<PR>`.
Use `Coordinator` for the thread responsible for integration and the landing queue.
For example, `Authoring/docs · verso-run · #16, #14` identifies a lane and its work
at a glance. Before a PR exists, use a short task name in its place.

Set the title when taking ownership and update it when PRs open, land, close, or
move to another writer. Include only owned work; record dependencies in GitHub.
The coordinator keeps the list of PRs still under its ownership as lanes take
over individual tasks. In Codex CLI,
[`/rename <title>`](https://learn.chatgpt.com/docs/developer-commands?surface=cli#rename-the-current-chat-with-rename)
updates the saved thread name. The title supplements the issue or PR's task record.

### Starting and handing over a task

Use an issue or a draft PR to record the intended change, its lane and writer,
the branch/worktree, any prerequisite PR, and how completion will be checked.
A small task can use its PR alone. Keep concrete task status in GitHub; do not
maintain a second status board in the roadmap or user guides.

Keep one active implementation per lane as the default. Start another when its
scope and dependencies are independent. One writer owns each task. When work
overlaps a file or API, agree which writer makes that change before editing;
different worktrees do not resolve conflicting ownership. This matters especially
for library source that contains both implementation and API documentation.
Reviewers can work alongside the writer without changing the same files.

Start from current `origin/main`, or from an agreed prerequisite PR when a stack
is needed. Record that dependency and keep the new patch separate. Do not begin
new implementation in an old checkout with preserved WIP. The worktree rules
below cover isolation and generated outputs.

On handoff, give the commit hash, worktree, completed and pending checks, any
blocker, and the next action. A blocked or unfinished task can be handed over;
keep any unfinished PR as a draft. Link the PR or retained evidence rather than copying the
work history into messages or guides.

### Landing and retirement

Keep one landing order for changes that depend on each other. Independent tasks
can proceed in parallel; downstream work should consume the selected API rather
than rebuilding it on another branch. After a prerequisite is squash-merged,
move only the dependent task's own changes onto the landed baseline and retarget
its PR to that branch (usually `main`). Check the resulting diff and validation
again before landing.

The integration owner identifies the revision served by a preview and reports
the merge and Pages deployment separately. A preview from a PR is useful, but it
must be distinguishable from the published `main` site.

Once a task lands, apply the cleanup procedure below. Closed or superseded PRs
need an extra check: identify the commits and evidence that preserve their work
before retiring a checkout. A closed PR alone is not proof that every local
change was incorporated. Keep dirty or unaccounted-for worktrees until their
contents have been reviewed. A preserved checkout is archival work, not an
active lane or the integration baseline.

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

Ordinary PRs target `main`. For an agreed stack, target the prerequisite branch
and link its PR so the review shows only the dependent task's changes. The example
below targets `main`:

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
outside disposable worktree outputs. Before deleting its branch, rebase and
retarget any open PRs that use it as their base, as described above. Keep the base
branch until their new bases and diffs have been checked. From the main checkout,
inspect and remove only that task's clean worktree:

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
qualifies that published revision; it does not select the current PR candidate.

Check downstream consumption of your committed candidate separately:

```sh
UV_CACHE_DIR="$PWD/.cache/uv" UV_PYTHON_INSTALL_DIR="$PWD/.cache/uv-python" \
  uv run --with playwright python tests/candidate-consumer.py --candidate HEAD --revision-kind pr-head
```

This gate bundles the exact checked-out commit and builds a fresh consumer outside
the workspace. The consumer owns its model, Manual, resource carrier, publisher,
and build outputs. Its scalar, finite, and live examples run from copied sites at
root and nested URLs, with native reference results and independent live sessions.
The report records the requested revision, resolved dependency, and dependency
checkout. It identifies local bundle acquisition separately from the starter's
public Git acquisition. CI tests its actual checkout, including synthetic PR
merge commits, and requires both gates before deploying Pages. Keep the starter's
public pin until a new baseline has landed and its acquisition is qualified.

## Writing documentation

User-facing explanations belong in the Verso manual under `doc/`, and public
view-library reference prose belongs beside the declarations in `src/views/`.
Keep README setup brief and link to those guides. Markdown remains the home for
contributor instructions, architecture, validation, history, and planning.
When moving a guide, leave a short pointer rather than maintaining two versions.

Write for a Lean programmer who has not read the project history. Start with
what an author can build and what readers can do with it. A useful default is to
introduce the capability, show a small example, explain the relevant API, and
then cover details. Choose the order that makes the explanation easiest to follow.

Describe supported capabilities broadly and accurately. Examples illustrate
possibilities; the current demos do not define the library's scope. For example,
introduce runnable functions and HTML results before explaining the optional
sequence and automaton helpers. Explain each concept before relying on its name.
Keep authors and readers distinct: authors define functions and their displays;
readers supply inputs and use the published controls.

Use plain sentences, concrete subjects, and headings that name the topic.
Explanatory prose describes concepts and their relationships. Save direct
instructions such as “select the function” for a task where that action makes
sense. Keep author and reader roles clear without narrating every action or
repeatedly addressing the author as “you”.
Explain necessary technical terms where they first matter. State behavior and
constraints when they affect a choice, or link to the relevant reference. Avoid
both unqualified promises and an introductory catalogue of restrictions.
Attribute behavior to the layer that provides it. For example, the compiled
presenter uses DOM APIs, while entry functions execute in a worker; internal
renderer capabilities do not imply an arbitrary author-facing DOM interface.

Show enough Lean code to make an example understandable. Keep examples beside
their explanations. Adapt explanations to each format; slides should leave room
for visible code and controls. Implementation details and proofs can remain available in
the reference without preceding the guide. Use Verso's HTML quotation for
examples that build markup; keep constructor calls when explaining escaping or
programmatic HTML construction. Prefer one canonical explanation with links to
it over repeated paragraphs that drift apart.

Match the content to its purpose:

- **Guides** explain a capability and help authors use it, with working examples
  and the choices needed for a real task.
- **API reference** explains types and functions, their arguments and results,
  relevant behavior and limits, and examples. Linked source supplements that
  explanation.
- **Architecture notes** explain implementation boundaries, dependencies, and
  design decisions. Keep project history and plans in their own documents.
- **PR descriptions** lead with the resulting behavior or concrete problem
  fixed. Include the design and validation needed for review, with material
  limits. Development chronology and internal coordination do not belong here.

For substantial prose changes, separate writing from review. The writer drafts
the explanation; the reviewer checks its claims against the code and reads the
rendered page, rather than just suggesting different wording. A human or an
agent can fill either role. Both should ask:

- Can a new author tell what they can build, beyond the examples shown?
- Are author actions, reader actions, and optional helpers clear?
- Are API terms explained, and capability claims accurate with useful links to
  their constraints?
- Do the headings and reading order help, with enough visible example code?
- Does the rendered page read naturally, with working links and without
  unexplained internal names or implementation details?

### Applying the principles

Before writing an overview, check the full capability of the library. A guide
to one helper should not become the description of the whole project. The
[README introduction](README.md#verso-run) is a worked example: it covers
primitive results, HTML, animated views, and experimental DOM rendering, with
the rendering boundary made explicit. Check these claims against the code as
the APIs evolve.

Two examples capture recurring editing decisions:

- “You select the function; readers supply an input” narrates setup in an
  introduction. Explain the capability there; describe `entry` when introducing
  the block's arguments. Direct instructions are useful in the setup procedure.
- “Record a few steps or keep running?” makes a heading sound like a prescribed
  workflow. A heading such as “Recorded and live views” names the concepts the
  section explains.

For documentation PRs, include links to the affected pages or preview commands
so the reviewer can read the output. Review meaning and English together;
automated checks cover examples, links, and rendering, rather than prescribing
particular wording. When a review reveals a recurring writing problem, update
this section. Keep it as the canonical guidance, with a short pointer in
`AGENTS.md`, rather than duplicating rules in agent prompts or other guides.

## Repository layout

### User guide and API reference

The user manual is a Verso Manual in `doc/VersoRunGuide.lean` and its chapter
modules. `doc/GuideMain.lean` is its native generator. The separate resource
carrier in `doc/resources/` embeds the programs for runnable guide examples;
document modules never import that carrier. The pure view library has no guide
or document-generation prerequisite.

Build and preview the guide:

```sh
python3 scripts/build-user-guide.py
python3 -m http.server 8797 --bind 127.0.0.1 --directory _out/guide/html-multi
```

Ordinary Lean snippets in the guide use Verso's checked code blocks. Complete
file templates, shell commands, and diagnostic excerpts use literal blocks.
Runnable examples use the same public adapters and resource workflow as other
consumers. Review the rendered guide after prose changes, including narrow
layouts and cross-chapter links.

`scripts/build-demo-site.py` publishes the guide under `/guide/` beside the
API reference at `/api/`. `tests/user-guide.py` checks its generated links,
search, examples, and root/nested deployment. User-facing Markdown files under
`docs/` are entry points to the manual, not another copy of its chapters.

### Generated library reference

Run `python3 scripts/build-api-reference.py` to generate the public view library's reference in
`.lake/build/literate-html/`. `literate.toml` selects `VersoLeanRunViews` and its
landing page; module prose and Lean-checked examples live with the library source.
For HTML quotation in checked examples, import `Lean.Data.Html` and use
`html%{…}`. Keep the `/-! ... -/` comment as a standalone command
so the pinned reference generator includes it. The copyable examples should
also show the namespace open they need when used in a document or Lean module.
Use `python3 -m http.server --directory .lake/build/literate-html` to preview it.
The helper invokes Verso's `lake build :literateHtml` facet and supplies the source
dependency missing from the pinned facet: documentation-only edits must refresh
HTML even when the public olean stays unchanged. It also tracks the configured
extra stylesheets so style edits refresh the generated site.
The configured CSS and JavaScript put checked examples before the expandable
declaration reference. Declaration links open the reference at their target.
Without JavaScript, the declarations remain visible below the guide. Keep all
generated declaration anchors intact when changing this presentation.
`scripts/build-demo-site.py` includes the reference at `/api/` in the demo and
Pages artifact. Generated HTML stays out of Git.

Use `lake test` for the reference's module scope, links, search, and root/nested
browser checks. To check a packaged reference directly, run:

```sh
UV_CACHE_DIR="$PWD/.cache/uv" UV_PYTHON_INSTALL_DIR="$PWD/.cache/uv-python" \
  uv run --with playwright python tests/api-reference.py --site _out/html-multi/api
```

### Source directories

| Path | Purpose |
| --- | --- |
| `src/views/` | Pure models, observations, and VIR worker-session adapters |
| `src/authoring/` | Shared block elaboration and console rendering |
| `src/manual/`, `src/blog/`, `src/slides/` | Genre adapters and public authoring imports |
| `src/publication/` | Shared resource planning and Manual publication |
| `src/presenter/` | VIR DOM rendering and sandbox policy |
| `src/presenter-resources/` | Native carrier for the prepared browser presenter |
| `web/` | Input validation, UI state, worker ownership, and asynchronous invocation |
| `doc/` | Verso user manual, checked examples, and native guide generator |
| `demo/chapters/` | Manual, Blog, and Slides documents and their Lean functions |
| `demo/generators/` | Native generators for the three demo genres |
| `demo/resources/` | Embedded program carriers; `lakefile.lean` owns module registration |
| `examples/manual-starter/` | Copyable independent author project |
| `tests/` | Native/browser acceptance and negative author fixtures |
| `docs/`, `evidence/` | Guide pointers, artwork, architecture, and qualification limits |

`demo/generators/DemoMain.lean` builds the Manual; `demo/generators/BlogMain.lean` builds the Blog site.
`demo/generators/SlidesMain.lean` builds the deck. `scripts/build-demo-site.py` combines them with a landing page.
`tests/native/OracleMain.lean` and `tests/native/BlogOracleMain.lean` supply native reference results.
`tests/native/PublicationMain.lean` checks resource registration with real bundles.
Generated Lake, Beam, VIR, browser, and site outputs stay out of Git.
Generated qualification reports and prototype captures belong in `_out/` or CI
artifacts; their earlier versions remain in Git history at `23f449e`. Keep only
illustrations used by documentation in `docs/images/`.

Within `src/authoring/`, `Model`, `Callable`, `Anchored`, `Inline`, `Render`,
and `Collect` hold the common authoring machinery. `Publication` in
`src/publication/` holds the shared resource planner. `Manual` and `Publish`
adapt it to Manual elaboration, native source blocks, and generator output.
`VersoLeanRun` remains the Manual authoring facade. `Blog` and `Blog.Publish`
adapt the same core to Page/Post. `Slides` and `Slides.Publish` retain native code
and compose with the stock Slides asset plan. See the [genre review](docs/multi-genre.md).

`Sequence` holds finite author states; `Automaton` holds pure live transitions
and worker sessions. `Frame` supplies their shared observations and typed
transport. `Preview` owns the sandbox document policy. `VersoLeanRunPresenter` implements browser DOM
presentation through VIR. Its separate resource carrier keeps browser-only
definitions out of native generator compilation. `web/presenter.js` owns loading,
cancellation and disposal for Html, sequence and automaton views.
`VersoLeanRun.Views` is the model/view import for ordinary producers. Its library
has no document or browser-asset prerequisite. Each library owns its source
directory; public import names remain unchanged. The Lake ownership table and
upstream import constraints are described in [internals](docs/internals.md#library-boundaries).

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

## Publishing the repository demo

Enable Pages in the repository settings with *GitHub Actions* as the source.
The main-branch workflow builds and validates the combined demo, user guide and
API reference, then deploys the complete `_out/html-multi` artifact. PRs validate
that package without deploying it. If Pages has not been enabled, the job reports
its settings link and skips deployment.

After deployment, regenerate local output and run
`uv run --with playwright python tests/pages-smoke.py` to check the live site's
programs, runtime, module bytes and MIME types against the local package.
Record hosted checks separately from local acceptance; a passing local build
alone does not establish what the public server is serving.
