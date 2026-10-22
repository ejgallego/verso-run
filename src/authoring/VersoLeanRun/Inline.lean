/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import VersoLeanRun.Callable
public meta import VersoManual.InlineLean
public meta import VersoManual.InlineLean.Scopes
public meta import Verso.Code.External
public section
open Lean Verso Doc Elab
open SubVerso.Highlighting (Highlighted)
open Verso.Genre.Manual.InlineLean

namespace VersoLeanRun

/-- Render retained commands through the genre's public highlighted-code instance. -/
meta def nativeRunSource (shouldShow : Bool) (hls : Highlighted)
    (_str : Lean.Doc.VersoCodeBlock) : DocElabM Term := do
  if !shouldShow then return ← ``(Verso.Doc.Block.concat #[])
  let col? := (← getRef).getPos? |>.map (← getFileMap).utf8PosToLspPos |>.map (·.character)
  let hls := match col? with
    | none => hls
    | some col => hls.deIndent col
  ``(Verso.Code.External.ExternalCode.leanBlock $(quote hls) {})

/-- Run definitions remain in the document environment. Verso's generic command
elaborator currently lives in the Manual library; no Manual AST is constructed here. -/
meta def retainedRunCommands : LeanBlockConfig :=
  { «show» := true, keep := true, name := none, error := false, fresh := false }

/-- Shared inline selection/registration, with native genre source rendering.
Slides supplies its formatting-aware command elaborator; Manual and Blog reuse
Verso's generic retained-command path. -/
meta def elabInlineRun (config : Config) (str : Lean.Doc.VersoCodeBlock)
    (source : Bool → Highlighted → Lean.Doc.VersoCodeBlock → DocElabM Term)
    (wrap : Experiment → Term → DocElabM Term)
    (elaborate : Lean.Doc.VersoCodeBlock → (Bool → Highlighted → Lean.Doc.VersoCodeBlock → DocElabM Term) → DocElabM Term :=
      fun str continuation => elabCommands retainedRunCommands str continuation) : DocElabM Term :=
  elaborate str fun shouldShow hls str => do
    let name ← liftM <| Scopes.runWithOpenDecls <|
      Lean.Elab.realizeGlobalConstNoOverloadWithInfo config.entry
    let experiment ← describeEntry config name str
    wrap experiment (← source shouldShow hls str)

end VersoLeanRun
