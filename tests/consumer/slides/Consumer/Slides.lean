module
public import VersoLeanRun.Slides
public import Consumer.Model
open Verso VersoSlides VersoLeanRun.Slides
set_option compiler.postponeCompile false

#doc (VersoSlides.Slides) "Typed result" =>

# Packet

```leanRun (entry := Consumer.packet) (input := "255")
#check Consumer.packet
```

# Next

Leaving the placement stops its worker and presentation.
