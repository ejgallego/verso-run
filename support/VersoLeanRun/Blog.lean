/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import VersoBlog
public import VersoLeanRun.Render
public meta import VersoLeanRun.Anchored
public meta import VersoLeanRun.Inline

public section
open Lean Verso Doc Elab Genre Blog Output Html

namespace VersoLeanRun.Blog

/-- Page and Post share one component, preserving native source children. -/
block_component leanRun (experiment : Experiment) where
  jsFiles := #[("verso-lean-run-bootstrap.js", include_str "../../web/bootstrap.js")]
  cssFiles := #[("verso-lean-run.css", include_str "../../web/lean-run.css")]
  toHtml := fun id _ _ go contents => do
    let source ← contents.mapM go
    let path := (← HtmlT.context).path
    let relativeRoot := String.join (List.replicate path.toList.length "../")
    return renderConsole experiment source (toString id)
      (some (relativeRoot ++ "lean-run/renderer.js"))

private meta def inlineSource (shouldShow : Bool) (hls : SubVerso.Highlighting.Highlighted)
    (_str : StrLit) : DocElabM Term := do
  if !shouldShow then return ← ``(Verso.Doc.Block.concat #[])
  let col? := (← getRef).getPos? |>.map (← getFileMap).utf8PosToLspPos |>.map (·.character)
  let hls := match col? with
    | Option.none => hls
    | Option.some col => hls.deIndent col
  ``(Verso.Code.External.ExternalCode.leanBlock $(quote hls) {})

/-- Page and Post use the same inline Run syntax and their native code renderer. -/
@[code_block leanRun]
meta def leanRunInline : CodeBlockExpanderOf Config
  | config, str => elabInlineRun config str inlineSource fun experiment source => do
    let description ← quoteExperiment experiment
    ``(VersoLeanRun.Blog.leanRun $description #[$source])

/-- Optional checked-source reuse for either Blog genre. -/
@[code_block_expander leanRunAnchor]
meta def leanRunAnchor : CodeBlockExpander
  | args, str => elabAnchoredRun (fun experiment source => do
      let description ← quoteExperiment experiment
      return #[← ``(VersoLeanRun.Blog.leanRun $description #[$source,*])]) args str

end VersoLeanRun.Blog
