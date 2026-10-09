module
public import VersoLeanRun
public import Illuminate.Diagram.Compile
open Verso Genre Manual VersoLeanRun Illuminate
set_option compiler.postponeCompile false
#doc (Manual) "Illuminate dependency gate" =>

```leanRun (entry := arrowAngle)
public def arrowAngle (_ : String) : String :=
  toString (Float.asin 0.5)
```
