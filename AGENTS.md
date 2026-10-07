# verso-lab contributor notes

This is an experimental Verso Manual extension for calling compiled Lean
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
