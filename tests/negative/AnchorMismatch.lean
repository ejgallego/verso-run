module
public import VersoLeanRun
import LeanRunGate.Helper
open Verso Genre Manual VersoLeanRun

#doc (Manual) "Anchor failure" =>

```leanRunAnchor twice (project := ".") (module := LeanRunGate.Helper) (entry := LeanRunGate.Helper.twice)
public def LeanRunGate.Helper.twice (n : Nat) : Nat := n + n + 1
```
