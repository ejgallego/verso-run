module
public import VersoLeanRun
public import Illuminate.Diagram.Compile
open Verso Genre Manual VersoLeanRun Illuminate
set_option compiler.postponeCompile false
#doc (Manual) "Illuminate dependency gate" =>

```leanRun (entry := fullDiagram)
@[vir_export]
public def fullDiagram (_ : String) : String :=
  (Diagram.circle (β := Empty) 20).renderDiagram
```
