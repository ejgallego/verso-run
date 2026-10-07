module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false
#doc (Manual) "Implicit argument" =>

```leanRun (entry := implicitExtra)
public def implicitExtra (n : Nat) {extra : Nat} : Nat :=
  n + extra
```
