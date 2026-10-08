module
public import VersoLeanRun.Blog
import LeanRunBlog.Examples

open Verso Genre Blog VersoLeanRun.Blog

#doc (Post) "Running Lean in a post" =>

%%%
authors := ["verso-run"]
date := {year := 2026, month := 10, day := 8}
%%%

These examples reuse source anchors from an ordinary compiled Lean module.
Edit an input, choose Run, and use Stop to interrupt the counting example.

# A greeting

```leanRunAnchor greeting (project := ".") (module := LeanRunBlog.Examples) (entry := LeanRunBlog.Examples.greet) (input := "Ada")
@[vir_export]
public def LeanRunBlog.Examples.greet (name : String) : String :=
  "Hello, " ++ name ++ "!"
```

```leanRunAnchor greeting (project := ".") (module := LeanRunBlog.Examples) (entry := LeanRunBlog.Examples.greet) (input := "Grace") +collapsed
@[vir_export]
public def LeanRunBlog.Examples.greet (name : String) : String :=
  "Hello, " ++ name ++ "!"
```

```leanRunAnchor card (project := ".") (module := LeanRunBlog.Examples) (entry := LeanRunBlog.Examples.card) (input := "Ada") (output := "html") +collapsed
public def LeanRunBlog.Examples.cardHtml (name : String) : Verso.Output.Html :=
  {{ <section style="padding:1rem;background:#edf5ff;border-radius:8px">
    <h2> "Hello, " {{name}} "!" </h2>
    <p> "This card was computed by Lean." </p>
  </section> }}

@[vir_export]
public def LeanRunBlog.Examples.card (name : String) : String :=
  (LeanRunBlog.Examples.cardHtml name).asString
```

Text interpolated into typed HTML is escaped before serialization.

```leanRunAnchor counting (project := ".") (module := LeanRunBlog.Examples) (entry := LeanRunBlog.Examples.count) (input := "10") +collapsed
public def LeanRunBlog.Examples.countLoop (n acc : Nat) : Nat :=
  match n with
  | 0 => acc
  | n + 1 => LeanRunBlog.Examples.countLoop n (acc + 1)

@[vir_export]
public def LeanRunBlog.Examples.count (n : Nat) : Nat :=
  LeanRunBlog.Examples.countLoop n 0
```

Try `1000000000000`, then press Stop while the worker counts.
