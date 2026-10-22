module
public import VersoLeanRun
public import LeanRunBlog.Examples
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false

-- Reserve the document-owned forwarding name with a different signature.
public def tests.negative.ImportedCollision.LeanRunBlog.Examples.card.leanRun
    (input : String) : String := input

#doc (Manual) "An imported export collision" =>

```leanRun (entry := LeanRunBlog.Examples.card)
#check LeanRunBlog.Examples.card
```
