import LeanRunGate.Chapter
import LeanRunGate.Resources
import LeanRunSlides.Resources
import VersoLeanRun.Publish
import Vir.Hash

open Verso Genre Manual

/-- Two individually valid bundles with the same generated module identity.
An extra support file changes content identity without changing the root interface. -/
def conflictingBundle : Vir.Resources.Bundle := Id.run do
  let #[original] := LeanRunGate.resources.programs
    | panic! "publication fixture requires one program"
  let bytes := "publication conflict control".toUTF8
  let path := "publication-conflict.txt"
  let descriptor := { original.descriptor with
    files := original.descriptor.files.push {
      path, mediaType := "text/plain", byteLength := bytes.size, sha256 := Vir.sha256 bytes } }
  return { original with
    descriptor := descriptor
    contentId := descriptor.contentId
    files := original.files.push { path, bytes } }

private def check (condition : Bool) (message : String) : IO Unit :=
  unless condition do throw <| IO.userError message

/-- Placement options do not change a binding; contract and target identities do.
Use real embedded program manifests to distinguish those conflicts. -/
private def checkBindings : IO Unit := do
  let rendered ← IO.ofExcept <| VersoLeanRun.experiments
    (fun (block : Manual.Block) => do
      if block.name == `VersoLeanRun.Block.leanRun then
        return some (← Lean.fromJson? block.data)
      return none) (%doc LeanRunGate.Chapter)
  let some original := rendered.find? (·.declaration == "LeanRunGate.greet")
    | throw <| IO.userError "binding fixture requires the greeting entry"
  let first := { original with sourceLine := 101, sourceColumn := 1 }
  let placement := { first with
    initialInput := "another placement"
    collapsed := first.collapsed.not
    form := ⟨.string .multiline, .text⟩
    sourceLine := 202
    sourceColumn := 2 }
  let resources ← IO.ofExcept <| VersoLeanRun.combineResources
    LeanRunGate.resources LeanRunSlides.resources
  let prepare := fun entries => VersoLeanRun.preparePublication entries resources
  let single ← IO.ofExcept <| prepare #[first]
  for entries in #[#[first, first], #[first, placement], #[placement, first]] do
    let repeated ← IO.ofExcept <| prepare entries
    check (repeated.plan.compress == single.plan.compress)
      "repeated placements changed publication bytes"
  -- The same declaration can appear in distinct documents; declaration and
  -- document keys must both participate in conflict detection.
  let anotherDocument := { placement with program := "AnotherDocument" }
  let anotherEntry := { placement with declaration := "AnotherEntry" }
  let independent ← IO.ofExcept <| prepare #[first, anotherDocument, anotherEntry]
  let reordered ← IO.ofExcept <| prepare #[anotherEntry, anotherDocument, first]
  check (independent.plan.compress == reordered.plan.compress)
    "binding order changed publication bytes"
  let owners ← IO.ofExcept <| independent.plan.getObjVal? "programs"
  let _ ← IO.ofExcept <| owners.getObjVal? "AnotherDocument"
  let entries ← IO.ofExcept <| owners.getObjVal? first.program
  let _ ← IO.ofExcept <| entries.getObjVal? "AnotherEntry"
  let _ ← IO.ofExcept <| entries.getObjVal? first.declaration
  for conflicting in #[{ placement with form := ⟨.nat, .text⟩ },
      { placement with producerModule := "LeanRunSlides.Deck" },
      { placement with callable := "AnotherCallable" }] do
    for entries in #[#[first, conflicting], #[conflicting, first]] do
      match prepare entries with
      | .ok _ => throw <| IO.userError "contradictory binding was silently accepted"
      | .error error =>
        for expected in #["PUBLICATION_BINDING_CONFLICT", first.declaration,
            s!"{first.program}:101:1", s!"{first.program}:202:2"] do
          check ((error.splitOn expected).length > 1) error
  let empty ← IO.ofExcept <| prepare #[]
  check ((← IO.ofExcept <| empty.plan.getObjVal? "programs") == Lean.Json.mkObj [])
    "empty document acquired a binding"
  IO.println "Publication bindings are idempotent, ordered, document-scoped, and reject conflicting signatures, manifests, or callables"

/-- Exercise public registration with real embedded bundles, using the normal generator. -/
def main (args : List String) : IO UInt32 := do
  let mode :: options := args
    | throw <| IO.userError "usage: lean-run-publication-check bindings|duplicate|missing|conflict [MANUAL OPTIONS]"
  if mode == "bindings" then
    checkBindings
    return 0
  let programs ← match mode with
    | "duplicate" => pure (LeanRunGate.resources.programs ++ LeanRunGate.resources.programs)
    | "missing" => pure #[]
    | "conflict" => pure (LeanRunGate.resources.programs.push conflictingBundle)
    | _ => throw <| IO.userError s!"unknown publication check {mode}"
  manualMain (%doc LeanRunGate.Chapter) (options := options)
    (extraSteps := [VersoLeanRun.publish { LeanRunGate.resources with programs }])
