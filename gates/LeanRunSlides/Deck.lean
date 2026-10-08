module
public import VersoLeanRun.Slides
import LeanRunGate.Helper
import LeanRunBlog.Examples

open Verso Doc VersoSlides VersoLeanRun.Slides

#doc (VersoSlides.Slides) "Lean you can run" =>

# Exact natural numbers

Edit the input and choose Run. Try `9007199254740993`: Lean keeps the exact value.
Use the arrows to change slides.

```leanRunAnchor twice (project := ".") (module := LeanRunGate.Helper) (entry := LeanRunGate.Helper.twice) (input := "21")
@[vir_export]
public def LeanRunGate.Helper.twice (n : Nat) : Nat := n + n
```

# A greeting, on reveal

Advance once to reveal the example. Its worker stops when the fragment is hidden.

:::fragment
```leanRunAnchor greeting (project := ".") (module := LeanRunBlog.Examples) (entry := LeanRunBlog.Examples.greet) (input := "Ada")
@[vir_export]
public def LeanRunBlog.Examples.greet (name : String) : String :=
  "Hello, " ++ name ++ "!"
```
:::

# Stop when you leave

Run `1000000000000`, then choose Stop or move to another slide.

```leanRunAnchor counting (project := ".") (module := LeanRunBlog.Examples) (entry := LeanRunBlog.Examples.count) (input := "10") +collapsed
public def LeanRunBlog.Examples.countLoop (n acc : Nat) : Nat :=
  match n with
  | 0 => acc
  | n + 1 => LeanRunBlog.Examples.countLoop n (acc + 1)

@[vir_export]
public def LeanRunBlog.Examples.count (n : Nat) : Nat :=
  LeanRunBlog.Examples.countLoop n 0
```

# An HTML card

The same isolated HTML preview works in a slide.

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
