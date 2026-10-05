module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false
#doc (Manual) "Negative author fixture" =>

```leanRun (entry := flag)
@[vir_export] public def flag (b : Bool) : Bool := b
```
