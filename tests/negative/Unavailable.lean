module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false
#doc (Manual) "Negative author fixture" =>

```leanRun (entry := value)
axiom absent : Nat → Nat
public noncomputable def value (n : Nat) : Nat := absent n
```
