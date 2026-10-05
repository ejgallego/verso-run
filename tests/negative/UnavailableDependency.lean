module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false
#doc (Manual) "Unavailable executable dependency" =>

```leanRun (entry := unsupportedExprText)
@[vir_export]
public def unsupportedExprText (name : String) : String :=
  (Lean.Expr.const (Lean.Name.mkSimple name) []).dbgToString
```
