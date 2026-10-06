module
public import VersoLeanRun
public import Illuminate.Diagram.Compile
open Verso Genre Manual VersoLeanRun Illuminate
set_option compiler.postponeCompile false
#doc (Manual) "Illuminate dependency gate" =>

```leanRun (entry := compiledDiagram)
@[vir_export]
public def compiledDiagram (_ : String) : String :=
  Svg.render (Diagram.circle (β := Empty) 20).compile
    ViewBox.fallback "local_"
```
