import VersoLeanRun.ResultPresenter
import VersoLeanRun.Result
import Lean.Elab.Command

open Lean VersoLeanRun Vir.Resources

namespace PresenterFixture
structure Packet where
  label : String
  bytes : ByteArray
instance : CustomResult Packet := ⟨⟩
def packet (input : String) : Packet := ⟨input, ⟨#[]⟩⟩
end PresenterFixture

private def result : ResultType := resultType% PresenterFixture.Packet
private def file (path : String) : File := ⟨path, ⟨#[]⟩⟩
private def presenter : ResultPresenter := {
  resultType := result
  workerModule := file "lean-run/packet/normalize.js"
  rendererModule := file "lean-run/packet/render.js"
}

#eval show IO Unit from do
  unless result.name == "PresenterFixture.Packet" do throw <| IO.userError "Wrong type key"
  let contract ← IO.ofExcept <| result.expectedExport .string
  unless (← IO.ofExcept <| contract.getObjValAs? String "effect") == "pure" do
    throw <| IO.userError "Expected a pure call"
  let (files, registry) ← IO.ofExcept <| ResultPresenter.inventory #[presenter] #[]
  unless files.size == 2 do throw <| IO.userError "Missing presenter assets"
  discard <| IO.ofExcept <| registry.getObjVal? result.name
  let reject (message : String) (presenters : Array ResultPresenter) (existing : Array File := #[]) := do
    match ResultPresenter.inventory presenters existing with
    | .error error => unless (error.splitOn message).length > 1 do throw <| IO.userError error
    | .ok _ => throw <| IO.userError s!"Expected rejection: {message}"
  reject "Duplicate" #[presenter, presenter]
  for path in #["../escape", "lean-run/../escape", "lean-run//empty", "lean-run/a?x", "outside.js"] do
    reject "Unsafe" #[{ presenter with workerModule := file path }]
  for path in #["lean-run/packet/normalize.js", "lean-run/PACKET/RENDER.js", "lean-run/packet", "lean-run/packet/render.js/child"] do
    reject "Colliding" #[{ presenter with files := #[file path] }]
  reject "Colliding" #[presenter] #[file "lean-run"]
  for input in #[InputKind.string .line, .string .multiline, .nat, .bool, .uint64] do
    let form : FormKind := ⟨input, .custom result.name⟩
    unless (← IO.ofExcept (fromJson? (toJson form) : Except String FormKind)) == form do
      throw <| IO.userError "Custom form round-trip failed"
  IO.println "PASS typed presenter contracts, inventory and metadata"

run_cmd Lean.Elab.Command.liftTermElabM do
  let info ← getConstInfo ``PresenterFixture.packet
  let .ok signature ← Vir.Interface.analyzeExportInterface info.type
    | throwError "Cannot classify fixture"
  let .ok classified := Json.parse signature.toExpectedSignatureJson
    | throwError "Invalid classifier JSON"
  let .ok published := result.expectedExport .string
    | throwError "Invalid publication contract"
  unless classified == published do throwError "Publisher contract differs from actual call"
