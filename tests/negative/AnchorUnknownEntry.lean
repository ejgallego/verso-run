module
public import VersoLeanRun
import LeanRunGate.Helper
open Verso Genre Manual VersoLeanRun

#doc (Manual) "Anchor failure" =>

```leanRunAnchor twice (project := ".") (module := LeanRunGate.Helper) (entry := Missing.entry)
public def LeanRunGate.Helper.twice (n : Nat) : Nat := n + n
```
