module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false
#doc (Manual) "Dependent result" =>

```leanRun (entry := bounded)
public def bounded (n : Nat) : Fin (n + 1) :=
  ⟨0, Nat.zero_lt_succ n⟩
```
