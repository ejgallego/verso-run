module
public import Lean.Data.Html

namespace Demo

public def greet (name : String) : String := "Hello, " ++ name

public def card (name : String) : Lean.Html :=
  html%{<h2>Hello, {name}!</h2>}

end Demo
