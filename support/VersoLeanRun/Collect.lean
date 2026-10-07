/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import VersoLeanRun.Model
public import Verso.Doc
public section

namespace VersoLeanRun

partial def blockExperiments {genre : Verso.Doc.Genre}
    (decode : genre.Block → Except String (Option Experiment)) (block : Verso.Doc.Block genre) : Except String (Array Experiment) := do
  let mut found := #[]
  let children ← match block with
    | .other container children => do
      if let some experiment ← decode container then
        found := found.push experiment
      pure children
    | .concat children | .blockquote children => pure children
    | .ul items | .ol _ items => pure <| items.flatMap (·.contents)
    | .dl items => pure <| items.flatMap (·.desc)
    | _ => pure #[]
  for child in children do
    found := found ++ (← blockExperiments decode child)
  return found

partial def experiments {genre : Verso.Doc.Genre}
    (decode : genre.Block → Except String (Option Experiment)) (part : Verso.Doc.Part genre) : Except String (Array Experiment) := do
  let mut found := #[]
  for block in part.content do found := found ++ (← blockExperiments decode block)
  for child in part.subParts do found := found ++ (← experiments decode child)
  return found

end VersoLeanRun
