module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false
#doc (Manual) "Invalid presentation" =>

```leanRun (entry := greeting) (output := "xml")
public def greeting (s : String) : String := s
```
