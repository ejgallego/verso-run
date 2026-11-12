module
public import VersoLeanRun.Cast
public import LeanRunInfoview.Helper

set_option compiler.postponeCompile false
open Verso Genre Manual VersoLeanRun

#doc (Manual) "Run source producers" =>

```leanRun (entry := inlineEcho) (input := "Ada")
public def inlineEcho (name : String) : String := "Hello, " ++ name
```

```leanRunAnchor double (project := ".") (module := LeanRunInfoview.Helper) (entry := LeanRunInfoview.double) (input := "21")
public def LeanRunInfoview.double (n : Nat) : Nat := n + n
```
