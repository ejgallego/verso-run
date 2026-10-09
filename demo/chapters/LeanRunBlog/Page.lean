module
public import VersoLeanRun.Blog
import LeanRunSequence.Examples
import LeanRunGate.Helper
import LeanRunTyped.Examples

open Verso Genre Blog VersoLeanRun.Blog

set_option compiler.postponeCompile false
set_option verso.exampleProject "."

#doc (Page) "A runnable Verso page" =>

A page can include the same checked source as a manual or a blog post.
Choose a natural number and run the imported function below. Inputs larger than
JavaScript's safe integer range remain exact.

```leanRunAnchor twice (module := LeanRunGate.Helper) (entry := LeanRunGate.Helper.twice) (input := "21")
public def LeanRunGate.Helper.twice (n : Nat) : Nat := n + n
```

[Read the runnable post](notes/2026-10-8-running-lean-in-a-post/).

# Typed inputs

Choose a Boolean or increment an exact unsigned 64-bit integer.

```leanRunAnchor flip (module := LeanRunTyped.Examples) (entry := LeanRunTyped.Examples.flip)
public def LeanRunTyped.Examples.flip (value : Bool) : Bool := !value
```

```leanRunAnchor increment (module := LeanRunTyped.Examples) (entry := LeanRunTyped.Examples.increment) (input := "9007199254740993")
public def LeanRunTyped.Examples.increment (value : UInt64) : UInt64 := value + 1
```

# Multiline text

Keep line breaks while editing. Ctrl+Enter or ⌘+Enter runs the example.

```leanRunAnchor lines (module := LeanRunTyped.Examples) (entry := LeanRunTyped.Examples.lines) (input := "Hello\nLean") +multiline +collapsed
public def LeanRunTyped.Examples.lines (text : String) : String :=
  String.intercalate "\n" <|
    (text.splitOn "\n").zipIdx.map fun (line, index) =>
      s!"{index + 1}. {line}"
```

# Define a runnable function here

Inline Run blocks compile their definitions in this document. No source anchor
or export annotation is needed. Later blocks can reuse the definition.

```leanRun (entry := LeanRunBlog.Page.Inline.greet) (input := "Ada")
namespace LeanRunBlog.Page.Inline
public def greet (name : String) : String :=
  "Hello, " ++ name ++ "!"
```

```leanRun (entry := greet) (input := "Grace") +collapsed
#check greet
```

# Return typed HTML

```leanRun (entry := LeanRunBlog.Page.Inline.card) (input := "Ada") +collapsed
public def card (name : String) : Verso.Output.Html :=
  .text true name
end LeanRunBlog.Page.Inline
```

# Stack stepper

Run a program, then choose a step to inspect its before and after stacks.

```leanRunAnchor stackView (module := LeanRunSequence.Examples) (entry := LeanRunSequence.Examples.stackView) (input := "6 7 * 2 +") +collapsed
public def stackView (program : String) : VersoLeanRun.SequenceView :=
  (evaluate program).view renderSnapshot
```
