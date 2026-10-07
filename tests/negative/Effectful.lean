module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false
#doc (Manual) "Effectful entry" =>

```leanRun (entry := echoIo)
@[vir_export]
public def echoIo (text : String) : IO String := pure text
```
