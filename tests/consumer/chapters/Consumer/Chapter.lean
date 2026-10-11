module
public import VersoLeanRun
public import Consumer.Model

open Verso Genre Manual VersoLeanRun
set_option compiler.postponeCompile false

#doc (Manual) "Independent consumer" =>

The model, document, carrier, and publisher belong to this project.

# Examples

```leanRun (entry := Consumer.increment) (input := "18446744073709551615")
#check Consumer.increment
```

```leanRun (entry := Consumer.finite) (input := "18446744073709551615")
#check Consumer.finite
```

```leanRun (entry := Consumer.live) (input := "18446744073709551615")
#check Consumer.live
```

```leanRun (entry := Consumer.live) (input := "7")
#check Consumer.live
```
