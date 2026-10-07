module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false
#doc (Manual) "Two-argument entry" =>

```leanRun (entry := combine)
@[vir_export]
public def combine (left right : String) : String :=
  left ++ right
```
