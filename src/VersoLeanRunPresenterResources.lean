module
public import Vir.Resources.Assets
public import Lean.Data.Json.Parser
public meta import Vir.Compiler.Interface.Classify.Signature
public meta import Vir.Compiler.Interface.Encode
public meta import Lean.Elab.Term
public section

open Lean Elab Term in
elab "presenterSignature%" declaration:ident : term => do
  -- Load the prepared program environment for its actual declaration type.
  -- Static imports would pull browser-only externs into the native generator.
  let env ← importModules #[{ module := `VersoLeanRunPresenter }] {}
  let signature ← withEnv env do
    let info ← getConstInfo declaration.getId
    let .ok signature ← Vir.Interface.analyzeExportInterface info.type
      | throwError "Cannot classify presenter export {declaration.getId}"
    return signature.toExpectedSignatureJson
  return mkStrLit signature

namespace VersoLeanRunPresenterResources
def resources : Vir.Resources.ResourceSet :=
  include_vir_assets (modules := #[VersoLeanRunPresenter])
/-- Full compiler-derived DOM contract; it is not a pure scalar form expectation. -/
def expectedMount : Except String Lean.Json :=
  Lean.Json.parse (presenterSignature% VersoLeanRun.Presenter.mount)
def expectedHtml : Except String Lean.Json :=
  Lean.Json.parse (presenterSignature% VersoLeanRun.Presenter.mountHtml)
def expectedAutomaton : Except String Lean.Json :=
  Lean.Json.parse (presenterSignature% VersoLeanRun.Presenter.showAutomaton)
end VersoLeanRunPresenterResources
