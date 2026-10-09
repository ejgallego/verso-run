# verso-run contributor notes

This is an experimental Verso Manual/Blog/Slides extension for calling compiled Lean
functions through VIR in a dedicated browser worker. Keep the existing
VersoLeanRun module API and the separation between elaboration, invocation,
resource publication, and rendering.

- Preserve exact Lean, Verso, VIR, and Illuminate pins unless a dependency
  update is explicitly part of the task. Runtime assets must match VIR's lock.
- Standard validation is `lake build` and `lake test -- --mutations`.
  Run these sequentially; mutation tests edit sources and restore them.
- Keep `.lake/`, `.beam/`, `.vir-generated/`, `_out/`, and browser caches out of Git.
- Keep generated demo resources out of source modules that depend on those
  resources: support → chapter → resource preparation → carrier → generator.
- Compiler scheduling and native precompilation remain deferred: retain
  `compiler.postponeCompile false` and the current package setup.
- Qualify only the Illuminate drawing-command/SVG path; general diagram
  rendering has recorded float-provider gaps in evidence/illuminate-gates.md.
- Use conventional commit subjects; explain changes and validation clearly.
- Keep pure scalar exports, expected compiler contracts, independent workers,
  real Stop, and static source/TeX fallback working.

## Development workflow

- Start new code work on a task branch in `.worktree/<task>/`, with one worktree
  per task. Keep the main checkout for integration and the local demo. Preserve
  existing working changes and legacy `.worktrees/` checkouts; do not relocate or
  discard them just to enforce this convention.
- Each worktree owns its build and generated outputs. Do not share these writable
  directories between concurrent tasks. Run builds and mutation tests sequentially
  within each worktree.
- Submit focused PRs against `main`, with a conventional title and a short
  description of the behavior, validation, and any remaining limits. Include a
  screenshot or demo instructions for visible changes. Use drafts for unfinished
  work, and report the PR URL when it is ready for review.
- Merge when the maintainer requests or approves it, after addressing review and
  checking CI on the exact current PR head. Squash merge by default; do not bypass
  checks. A merge to `main` also triggers the Pages deployment.
- After a confirmed merge, preserve needed evidence, remove only the task's clean
  worktree, and delete its merged branches. Never force-remove dirty worktrees or
  perform broad cleanup. Leave unrelated worktrees and working changes alone.

Commands and the squash-merge branch cleanup procedure are in
[CONTRIBUTING.md](CONTRIBUTING.md#worktrees-and-pull-requests).
