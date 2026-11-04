/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module

/-!
# Custom results

A document extension can present a concrete result type with its own display,
such as a plot or an audio player. The computation stays an ordinary Lean
function. Its result type has a {lit}`CustomResult`
instance, and the native publisher registers the matching presentation.
HTML, sequences and automata already have built-in displays and need no marker.
-/

public section
namespace VersoLeanRun

/-- Opt a concrete result type into a document extension's presentation.

The native publisher must register a matching `ResultPresenter`. This marker
does not change the value or its VIR interface, and imports no document or
compiler machinery. Built-in scalar and Lean views need no instance.
-/
class CustomResult (α : Type) : Prop where

end VersoLeanRun

/-!
## A result type

The marker contains no data and does not change the value or its compiler
interface. It only admits the result type to an ordinary {lit}`leanRun` block:

```lean
open VersoLeanRun

structure Samples where
  caption : String
  bytes : ByteArray

instance : CustomResult Samples := ⟨⟩

def samples (caption : String) : Samples :=
  { caption, bytes := ⟨#[0, 127, 255]⟩ }
```

An instance alone does not supply a renderer. The document's native publisher
also needs the result type's compiler-derived contract, a worker normalizer and
a result renderer. The
[extension interface](https://github.com/ejgallego/verso-run/blob/main/docs/internals.md#custom-result-presenters)
describes that registration and its lifecycle. This module imports no document,
compiler or browser machinery, so the producer can also be used natively.
-/
