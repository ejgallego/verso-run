module
public import Vir.Resources.Assets
public meta import Vir.Compiler.Interface.Classify.Signature
public meta import Vir.Compiler.Interface.Encode
public meta import Lean.Elab.Term
public section

open Lean Elab Term in
elab "sequenceMountSignature%" : term => do
  -- Load the prepared program environment for its actual declaration type.
  -- Static imports would pull browser-only externs into the native generator.
  let env ← importModules #[{ module := `VersoLeanRunPresenter }] {}
  let signature ← withEnv env do
    let info ← getConstInfo `VersoLeanRun.Presenter.mount
    let .ok signature ← Vir.Interface.analyzeExportInterface info.type
      | throwError "Cannot classify the sequence presenter"
    return signature.toExpectedSignatureJson
  return mkStrLit signature

namespace VersoLeanRunPresenterResources
def bundle : Vir.Resources.Bundle := (include_vir_assets (modules := #[VersoLeanRunPresenter])).programs[0]!
def expectedMount : String := sequenceMountSignature%
end VersoLeanRunPresenterResources
