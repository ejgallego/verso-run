/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import VersoManual
public import VersoLeanRun.Callable
public import VersoLeanRun.Render
public meta import VersoLeanRun.Anchored
public meta import VersoLeanRun.Inline
public import VersoManual.ExternalLean
public meta import VersoManual.InlineLean
public meta import VersoManual.InlineLean.Scopes
public section
open Lean Verso Doc Elab Genre Manual ArgParse
open Verso.Genre.Manual.InlineLean
namespace VersoLeanRun

block_extension Block.leanRun (experiment : Experiment) where
  data := toJson experiment
  traverse _ _ _ := pure none
  toTeX := some <| fun _ go _ _ contents => contents.mapM go
  toHtml := some <| fun _ go id data contents => do
    let .ok experiment := fromJson? (α := Experiment) data
      | reportError "Invalid Lean Run experiment description" *> pure .empty
    let source ← contents.mapM go
    pure <| renderConsole experiment source (toString id)
  extraJs := [include_str "../../web/bootstrap.js"]
  extraCss := [include_str "../../web/lean-run.css"]

/-- Elaborate ordinary retained commands, then resolve and classify the selected entry. -/
@[code_block]
meta def leanRun : CodeBlockExpanderOf Config
  | config, str => do
    elabInlineRun config str toHighlightedLeanBlock fun experiment source => do
      let description ← quoteExperiment experiment
      ``(Verso.Doc.Block.other (VersoLeanRun.Block.leanRun $description) #[$source])

/-- Run an explicit imported entry while displaying its standard Verso source anchor. -/
@[code_block_expander leanRunAnchor]
meta def leanRunAnchor : CodeBlockExpander
  | args, str => elabAnchoredRun (fun experiment source => do
      let description ← quoteExperiment experiment
      return #[← ``(Verso.Doc.Block.other (VersoLeanRun.Block.leanRun $description) #[$source,*])]) args str

end VersoLeanRun
