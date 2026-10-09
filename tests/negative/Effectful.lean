module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false
#doc (Manual) "Effectful entry" =>

```leanRun (entry := echoIo)
public def echoIo (text : String) : IO String := pure text
```
