module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false
#doc (Manual) "Unavailable executable dependency" =>

```leanRun (entry := unsupportedExprText)
public def unsupportedExprText (name : String) : String :=
  (Lean.Expr.const (Lean.Name.mkSimple name) []).dbgToString
```
