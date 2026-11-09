import CastSourceGate
import VersoLeanRun.Collect
import VersoLeanRun.Contract
import VersoManual.ExternalLean
import Verso.Code.External.Config
import Verso.Code.Highlighted

open Verso Genre Manual VersoLeanRun

private partial def externalBlocks (node : Verso.Doc.Block Verso.Genre.Manual) :
    Array Verso.Genre.Manual.Block :=
  match node with
  | .other container children =>
    let own : Array Verso.Genre.Manual.Block :=
      if container.name == `Verso.Genre.Manual.Block.lean then #[container] else #[]
    children.foldl (fun found child => found ++ externalBlocks child) own
  | .concat children => children.foldl (fun found child => found ++ externalBlocks child) #[]
  | _ => #[]

#eval show IO Unit from do
  IO.FS.createDirAll "_out/rc2-demo"
  let part := %doc CastSourceGate
  let entries ← IO.ofExcept <| experiments (fun (block : Verso.Genre.Manual.Block) => do
    if block.name == `VersoLeanRun.Block.leanRun then return some (← Lean.fromJson? block.data)
    return none) part
  unless entries.size == 2 do throw <| IO.userError "Expected both authoring paths"
  let blocks := part.content.flatMap externalBlocks
  unless blocks.size == 2 do throw <| IO.userError "Expected two real external source blocks"
  for block in blocks do
    let .arr #[config, highlighted, names] := block.data
      | throw <| IO.userError "Expected the producer's flat external-source payload"
    discard <| IO.ofExcept <| Lean.fromJson? (α := Verso.Code.External.CodeConfig) config
    discard <| IO.ofExcept <| Lean.fromJson? (α := SubVerso.Highlighting.Highlighted) highlighted
    let .arr names := names | throw <| IO.userError "Expected producer names"
    unless !names.isEmpty do throw <| IO.userError "Missing highlighted producer names"
  IO.println "PASS actual leanRun and leanRunAnchor external source layouts"
  IO.FS.writeFile "_out/rc2-demo/source-document.json" (Lean.toJson part).compress

#eval show IO Unit from do
  let part := %doc CastSourceGate
  let entries ← IO.ofExcept <| experiments (fun (block : Verso.Genre.Manual.Block) => do
    if block.name == `VersoLeanRun.Block.leanRun then return some (← Lean.fromJson? block.data)
    return none) part
  let contracts ← entries.mapM fun entry => do
    let expected ← IO.ofExcept entry.form.expectedExport
    pure <| Lean.Json.mkObj [("description", entry.browserDescription), ("expectedExport", expected)]
  IO.FS.writeFile "_out/rc2-demo/source-contracts.json" (Lean.Json.arr contracts).compress
