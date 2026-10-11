module
public import Vir.Resources.Assets
public meta import Vir.Compiler.Interface.Classify.Signature
public meta import Vir.Compiler.Interface.Encode
public meta import Lean.Elab.Term
public section

open Lean Elab Term in
elab "clientSignature%" declaration:ident : term => do
  let env ← importModules #[{ module := `ClientFixture }] {}
  let signature ← withEnv env do
    let info ← getConstInfo declaration.getId
    let .ok signature ← Vir.Interface.analyzeExportInterface info.type
      | throwError "Cannot classify client export {declaration.getId}"
    return signature.toExpectedSignatureJson
  return mkStrLit signature

namespace ClientResources
def resources : Vir.Resources.ResourceSet :=
  include_vir_assets (modules := #[ClientFixture])

def expectedTrace : String := clientSignature% ClientFixture.trace
def expectedStart : String := clientSignature% ClientFixture.start
end ClientResources
