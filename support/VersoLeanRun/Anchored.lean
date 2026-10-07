/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import VersoLeanRun.Callable
public meta import Verso.Code.External

public section
open Lean Verso Doc Elab ArgParse Code.External

namespace VersoLeanRun

structure AnchorConfig where
  anchor : Ident
  run : Config
  source : CodeModuleContext

meta instance : FromArgs AnchorConfig DocElabM where
  fromArgs := AnchorConfig.mk <$> .positional' `anchor <*> fromArgs <*> fromArgs

/-- Shared anchored authoring path. The adapter wraps native source terms in its
own Run block. Standard Verso code-body checks and highlighting remain authoritative.
Only imported, same-project scalar producers are qualified in this first slice. -/
meta def elabAnchoredRun
    (wrap : Experiment → Array Term → DocElabM (Array Term))
    (args : Array Arg) (str : StrLit) : DocElabM (Array Term) := do
  let config ← parseThe AnchorConfig args
  let project ← IO.FS.realPath config.source.project.getString
  let current ← IO.FS.realPath "."
  unless project == current do
    throwErrorAt config.source.project "Lean Run anchors currently require the document's own project. \
      Use (project := \".\") and import the producer module; external-project execution is not yet qualified."
  withAnchored config.source.project config.source.module (some config.anchor) fun hl => do
    let name ← liftM <| Lean.Elab.realizeGlobalConstNoOverloadWithInfo config.run.entry
    unless hl.definedNames.contains name do
      throwErrorAt config.run.entry "Lean Run entry '{name}' is not defined in anchor '{config.anchor.getId}' \
        of module '{config.source.module.getId}'. Choose an entry defined in the selected source region."
    let experiment ← describeEntry config.run name str (allowHtml := false)
    let sourceArgs := args.filter fun
      | .named _ name _ => !([`entry, `input, `output].contains name.getId)
      | .flag _ name _ => name.getId != `collapsed
      | _ => true
    -- The second lookup uses Verso's populated cache. Delegate body validation,
    -- replacement suggestions, and native ExternalCode construction unchanged.
    let source ← Verso.Code.External.anchor sourceArgs str
    wrap experiment source

end VersoLeanRun
