module
public import VersoLeanRun.Blog
import LeanRunSequence.Examples
import LeanRunRendered.Examples
import LeanRunSequence.Life
import LeanRunBlog.Examples

open Verso Genre Blog VersoLeanRun.Blog

set_option compiler.postponeCompile false
set_option verso.exampleProject "."

#doc (Post) "Running Lean in a post" =>

%%%
authors := ["verso-run"]
date := {year := 2026, month := 10, day := 8}
%%%

These examples reuse source anchors from an ordinary compiled Lean module.
Edit an input, choose Run, and use Stop to interrupt the counting example.

# A greeting

```leanRunAnchor greeting (module := LeanRunBlog.Examples) (entry := LeanRunBlog.Examples.greet) (input := "Ada")
public def LeanRunBlog.Examples.greet (name : String) : String :=
  "Hello, " ++ name ++ "!"
```

```leanRunAnchor greeting (module := LeanRunBlog.Examples) (entry := LeanRunBlog.Examples.greet) (input := "Grace") +collapsed
public def LeanRunBlog.Examples.greet (name : String) : String :=
  "Hello, " ++ name ++ "!"
```

```leanRunAnchor card (module := LeanRunBlog.Examples) (entry := LeanRunBlog.Examples.card) (input := "Ada") +collapsed
public def LeanRunBlog.Examples.card (name : String) : Verso.Output.Html :=
  {{ <section style="padding:1rem;background:#edf5ff;border-radius:8px">
    <h2> "Hello, " {{name}} "!" </h2>
    <p> "This card was computed by Lean." </p>
  </section> }}
```

Text interpolated into typed HTML is escaped before serialization.

```leanRunAnchor counting (module := LeanRunBlog.Examples) (entry := LeanRunBlog.Examples.count) (input := "10") +collapsed
public def LeanRunBlog.Examples.countLoop (n acc : Nat) : Nat :=
  match n with
  | 0 => acc
  | n + 1 => LeanRunBlog.Examples.countLoop n (acc + 1)

public def LeanRunBlog.Examples.count (n : Nat) : Nat :=
  LeanRunBlog.Examples.countLoop n 0
```

Try `1000000000000`, then press Stop while the worker counts.

# Define a runnable function here

Inline Run blocks compile their definitions in this document. No source anchor
or export annotation is needed. Later blocks can reuse the definition.

```leanRun (entry := LeanRunBlog.Post.Inline.greet) (input := "Ada")
namespace LeanRunBlog.Post.Inline
public def greet (name : String) : String :=
  "Hello, " ++ name ++ "!"
```

```leanRun (entry := greet) (input := "Grace") +collapsed
#check greet
```

# Return typed HTML

```leanRun (entry := LeanRunBlog.Post.Inline.card) (input := "Ada") +collapsed
public def card (name : String) : Verso.Output.Html :=
  .text true name
end LeanRunBlog.Post.Inline
```

# Stack stepper

Run a program, then choose a step to inspect its before and after stacks.

```leanRunAnchor stackView (module := LeanRunSequence.Examples) (entry := LeanRunSequence.Examples.stackView) (input := "6 7 * 2 +") +collapsed
public def stackView (program : String) : VersoLeanRun.SequenceView :=
  (evaluate program).view renderSnapshot
```

# Typed rendering

The input type selects its control; the result type selects its view.

```leanRunAnchor badge (module := LeanRunRendered.Examples) (entry := LeanRunRendered.Examples.badge) (input := "true") +collapsed
public def badge (enabled : Bool) : Html :=
  {{ <p><strong>{{if enabled then "Enabled" else "Disabled"}}</strong></p> }}
```

```leanRunAnchor wordSteps (module := LeanRunRendered.Examples) (entry := LeanRunRendered.Examples.wordSteps) (input := "18446744073709551615") +collapsed
public def wordSteps (seed : UInt64) : SequenceView :=
  let sequence : Sequence UInt64 := {
    initial := { label := "Start", state := seed }
    steps := #[{ label := "Increment", state := seed + 1 }] }
  sequence.view fun word => {{ <p> "Exact word: " {{toString word}}</p> }}
```

# Game of Life

Edit a rectangular seed: `#` is a live cell and `.` is a dead cell. The seed is
centred on an 8×8 board; cells outside the edge stay dead. Lean computes twelve
generations. Choose a generation or use Previous/Next to watch a glider move.
Try `###` on one line for a blinker, or `##` on each of two lines for a still life.

```leanRunAnchor lifeView (module := LeanRunSequence.Life) (entry := LeanRunSequence.Life.lifeView) (input := ".#.\n..#\n###") +multiline +collapsed
public def lifeView (seed : String) : VersoLeanRun.SequenceView :=
  match parse seed with
  | .error message => SequenceView.error message
  | .ok board => (simulate board).view renderState
```
