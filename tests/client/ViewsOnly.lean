module
import VersoLeanRun.Views
meta import Lean.Elab.Command

-- Models and their HTML displays use the standard library and VIR runtime.
-- Verso authoring, VIR compilation and DOM bindings stay outside this view API.
run_cmd do
  let env ← Lean.getEnv
  for name in env.header.moduleNames do
    for forbidden in #[`Verso, `VersoManual, `VersoBlog, `VersoSlides,
        `Verso.Doc, `Verso.Genre, `Vir.Compiler, `Vir.Attributes, `Vir.Browser,
        `VersoLeanRun.Manual, `VersoLeanRun.Callable, `VersoLeanRun.Publication,
        `VersoLeanRunPresenter] do
      if forbidden.isPrefixOf name then
        throwError "Views imported authoring or browser machinery: {name}"
