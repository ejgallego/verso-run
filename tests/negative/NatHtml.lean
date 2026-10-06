module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false
#doc (Manual) "Invalid HTML interface" =>

```leanRun (entry := numeric) (output := "html")
@[vir_export] public def numeric (n : Nat) : Nat := n
```
