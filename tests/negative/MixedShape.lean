module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false
#doc (Manual) "Different scalar types" =>

```leanRun (entry := textLength)
@[vir_export]
public def textLength (text : String) : Nat := text.length
```
