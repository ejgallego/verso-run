module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false
#doc (Manual) "Polymorphic entry" =>

```leanRun (entry := polymorphic)
public def polymorphic (α : Type) (value : α) : α := value
```
