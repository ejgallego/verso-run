/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public section
namespace VersoLeanRun

/-- Opt a concrete result type into a document extension's presentation.

The native publisher must register a matching `ResultPresenter`. This marker
does not change the value or its VIR interface, and imports no document or
compiler machinery. Built-in scalar and Lean views need no instance.
-/
class CustomResult (α : Type) : Prop where

end VersoLeanRun
