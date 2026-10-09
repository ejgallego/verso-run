/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import VersoSlides
public import VersoLeanRun.Render
public import Verso.Code.External
public meta import VersoLeanRun.Anchored
public meta import VersoLeanRun.Inline
public meta import VersoSlides.InlineLean

public section
open Lean Verso Doc Elab Output Html Code.External
open SubVerso.Highlighting (Highlighted hlToExport)
open VersoSlides

namespace VersoLeanRun.Slides

/-- Preserve native proof-state data unless the author explicitly hides it. -/
partial def proofPolicy (showStates : Bool) : Highlighted → Highlighted
  | .tactics info start stop content =>
    if showStates then .tactics info start stop (proofPolicy showStates content)
    else proofPolicy showStates content
  | .seq contents => .seq (contents.map (proofPolicy showStates))
  | .span info content => .span info (proofPolicy showStates content)
  | other => other

/-- Use Slides' fragmentization and native renderers for externally loaded code. -/
instance : ExternalCode VersoSlides.Slides where
  leanInline hl cfg := .other (.leanCode (hlToExport (proofPolicy cfg.showProofStates hl))) #[]
  leanBlock hl cfg :=
    let hl := proofPolicy cfg.showProofStates hl
    match fragmentize hl with
    | .ok code => .other (.slideCode (scToExport code) false false) #[]
    | .error _ => .other (.leanCode (hlToExport hl) false) #[]
  leanOutputInline message plain expandTraces :=
    if plain then .code (message.contents.toString expandTraces)
    else .other (.leanCode (hlToExport (.point message.severity message.contents))) #[]
  leanOutputBlock message summarize expandTraces :=
    let body := message.contents.toString expandTraces
    let output := {{ <pre class="hl lean lean-output"> {{body}} </pre> }}
    .other (.ofHtml (if summarize then
      {{ <details><summary> "Expand..." </summary> {{output}} </details> }} else output)) #[]

/-- Keep native source children in the typed tree while sharing the console. -/
def leanRun (experiment : Experiment) (source : Array (Block VersoSlides.Slides)) : Block VersoSlides.Slides :=
  .other (.wrap #[("class", "lean-run lean-run-slides"),
    ("data-verso-lean-run", "1"), ("data-experiment", (toJson experiment).compress),
    ("data-lean-run-renderer", "lean-run/renderer.js")]) #[
      .other (.wrap #[("class", "lean-run-source")]) source,
      .other (.ofHtml (renderControls experiment)) #[]]

private meta def inlineSource (shouldShow : Bool) (hls : Highlighted)
    (str : StrLit) : DocElabM Term := do
  if !shouldShow then return ← ``(Verso.Doc.Block.concat #[])
  let col? := (← getRef).getPos? |>.map (← getFileMap).utf8PosToLspPos |>.map (·.character)
  let hls := match col? with
    | none => hls
    | some col => hls.deIndent col
  match fragmentize hls.trim with
  | .ok code =>
    ``(Verso.Doc.Block.other (VersoSlides.BlockExt.slideCode $(quote (scToExport code)) false false)
      #[Verso.Doc.Block.code $(quote str.getString)])
  | .error message => throwErrorAt str message

/-- Inline Run retains Slides' native formatting and fragment data. -/
@[code_block leanRun]
meta def leanRunInline : CodeBlockExpanderOf Config
  | config, str => elabInlineRun config str inlineSource (fun experiment source => do
      let description ← quoteExperiment experiment
      ``(VersoLeanRun.Slides.leanRun $description #[$source]))
    (elaborate := fun str continuation =>
      VersoSlides.elabCommandsWithFormat retainedRunCommands str continuation)

@[code_block_expander leanRunAnchor]
meta def leanRunAnchor : CodeBlockExpander
  | args, str => elabAnchoredRun (fun experiment source => do
      let description ← quoteExperiment experiment
      return #[← ``(VersoLeanRun.Slides.leanRun $description #[$source,*])]) args str

end VersoLeanRun.Slides
