module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false
#doc (Manual) "Negative Boolean HTML fixture" =>

```leanRun (entry := boolHtmlValue) (output := "html")
public def boolHtmlValue (value : Bool) : Bool := !value
```
