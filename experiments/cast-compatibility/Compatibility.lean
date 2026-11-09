/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license. -/
module
public import VersoCast
public import VersoCast.Manual
public import VersoManual.ExternalLean

open Verso Doc Genre Code.External

-- Exercise the actual pinned producer, independently of a hand-written payload.
def externalSource : Verso.Doc.Block Manual :=
  ExternalCode.leanBlock (.text "public def twice (n : Nat) := n + n") {}

#guard match externalSource with
  | .other extension children =>
    extension.name == `Verso.Genre.Manual.Block.lean && children.isEmpty &&
      match extension.data with
      | .arr #[_, _, _] => true
      | _ => false
  | _ => false

-- These distinct source producers require separate decoders.
#check Verso.Genre.Manual.Block.lean
#check Verso.Genre.Manual.InlineLean.Block.lean
#check VersoCast.Manual.createRenderers
#check VersoCast.Highlighting.render
