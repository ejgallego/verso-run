import LeanRunGate.Chapter
import LeanRunGate.Resources
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

/-- Exercise public registration with real embedded bundles, using the normal generator. -/
def main (args : List String) : IO UInt32 := do
  let mode :: options := args
    | throw <| IO.userError "usage: lean-run-publication-check duplicate|missing|conflict|legacy [MANUAL OPTIONS]"
  let programs ← match mode with
    | "duplicate" => pure (LeanRunGate.resources.programs ++ LeanRunGate.resources.programs)
    | "legacy" => pure LeanRunGate.resources.programs
    | "missing" => pure #[]
    | "conflict" => pure (LeanRunGate.resources.programs.push conflictingBundle)
    | _ => throw <| IO.userError s!"unknown publication check {mode}"
  manualMain (%doc LeanRunGate.Chapter) (options := options)
    (extraSteps := [VersoLeanRun.publish programs])
