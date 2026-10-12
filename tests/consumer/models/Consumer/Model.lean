module
public import VersoLeanRun.Views
public section

namespace Consumer
open VersoLeanRun

-- The same UInt64 transition used by the document-free client fixture.
def counter (seed : UInt64) : Automaton UInt64 :=
  { initial := seed, step := (· + 1) }

def finite (seed : UInt64) : Sequence UInt64 :=
  (counter seed).trace 3

def live (seed : UInt64) : Automaton UInt64 :=
  counter seed

def increment (seed : UInt64) : UInt64 := seed + 1

end Consumer
