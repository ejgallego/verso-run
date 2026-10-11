module
public import VersoLeanRun.Views
public meta import Vir.Attributes
public section
open VersoLeanRun
namespace ClientFixture

def machine (seed : UInt64) : Automaton UInt64 :=
  { initial := seed, step := (· + 1) }

@[vir_export]
def trace (seed : UInt64) : SequenceWire.Payload :=
  ((machine seed).trace 3).viewText.toPayload

@[vir_export]
def start (seed : UInt64) : Lean.Vir.RuntimeM AutomatonWire.Session :=
  (machine seed).viewText.start

end ClientFixture
