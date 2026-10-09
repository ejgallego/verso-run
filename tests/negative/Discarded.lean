module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false
#doc (Manual) "Negative author fixture" =>

```leanRun (entry := value) -keep
public def value (n : Nat) : Nat := n
```
