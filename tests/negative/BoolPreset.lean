module
public import VersoLeanRun
open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false
#doc (Manual) "Negative Boolean preset fixture" =>

```leanRun (entry := boolPresetValue) (input := "maybe")
public def boolPresetValue (value : Bool) : Bool := value
```
