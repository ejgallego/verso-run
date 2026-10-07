module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun

#doc (Manual) "Anchor failure" =>

```leanRunAnchor twice (project := ".") (module := LeanRunGate.Helper) (entry := LeanRunGate.Helper.twice)
@[vir_export]
public def LeanRunGate.Helper.twice (n : Nat) : Nat := n + n
```
