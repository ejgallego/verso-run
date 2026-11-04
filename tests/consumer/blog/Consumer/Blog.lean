module
public import VersoLeanRun.Blog
public import Consumer.Model
open Verso Genre Blog VersoLeanRun.Blog
set_option compiler.postponeCompile false

#doc (Page) "Typed result" =>

```leanRun (entry := Consumer.packet) (input := "255")
#check Consumer.packet
```
