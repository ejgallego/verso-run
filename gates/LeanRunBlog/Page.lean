module
public import VersoLeanRun.Blog
import LeanRunGate.Helper

open Verso Genre Blog VersoLeanRun.Blog

#doc (Page) "A runnable Verso page" =>

A page can include the same checked source as a manual or a blog post.
Choose a natural number and run the imported function below. Inputs larger than
JavaScript's safe integer range remain exact.

```leanRunAnchor twice (project := ".") (module := LeanRunGate.Helper) (entry := LeanRunGate.Helper.twice) (input := "21")
@[vir_export]
public def LeanRunGate.Helper.twice (n : Nat) : Nat := n + n
```

[Read the runnable post](notes/2026-10-8-running-lean-in-a-post/).
