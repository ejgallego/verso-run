module
public meta import Vir.Attributes
public import Verso.Output.Html

open Verso.Output.Html

set_option compiler.postponeCompile false

-- ANCHOR: greeting
@[vir_export]
public def LeanRunBlog.Examples.greet (name : String) : String :=
  "Hello, " ++ name ++ "!"
-- ANCHOR_END: greeting

-- ANCHOR: card
public def LeanRunBlog.Examples.cardHtml (name : String) : Verso.Output.Html :=
  {{ <section style="padding:1rem;background:#edf5ff;border-radius:8px">
    <h2> "Hello, " {{name}} "!" </h2>
    <p> "This card was computed by Lean." </p>
  </section> }}

@[vir_export]
public def LeanRunBlog.Examples.card (name : String) : String :=
  (LeanRunBlog.Examples.cardHtml name).asString
-- ANCHOR_END: card

-- ANCHOR: counting
public def LeanRunBlog.Examples.countLoop (n acc : Nat) : Nat :=
  match n with
  | 0 => acc
  | n + 1 => LeanRunBlog.Examples.countLoop n (acc + 1)

@[vir_export]
public def LeanRunBlog.Examples.count (n : Nat) : Nat :=
  LeanRunBlog.Examples.countLoop n 0
-- ANCHOR_END: counting
