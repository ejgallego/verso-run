module
public import VersoLeanRun
import LeanRunGate.Helper
open Verso Genre Manual VersoLeanRun

#doc (Manual) "Anchor failure" =>

```leanRunAnchor twice (project := ".") (module := LeanRunGate.Helper) (entry := Nat.add)
public def LeanRunGate.Helper.twice (n : Nat) : Nat := n + n
```
