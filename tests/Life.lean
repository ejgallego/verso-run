module
public import LeanRunSequence.Life
public meta import LeanRunSequence.Life
open LeanRunSequence.Life
instance : Inhabited Board := ⟨{}⟩

def board (seed : String) : Board :=
  match parse seed with
  | .ok b => b
  | .error message => panic! message

-- Known configurations qualify the rules independently of browser/native agreement.
#guard (board ".##.\n.##.").step == board ".##.\n.##."
#guard (board "...\n###\n...").step == board ".#.\n.#.\n.#."
#guard (board "...\n###\n...").step.step == board "...\n###\n..."
#guard (board "#").step.population == 0

def glider := board ".#.\n..#\n###"
def shiftedGlider := board "........\n........\n........\n....#...\n.....#..\n...###..\n........\n........"
#guard glider.step.step.step.step == shiftedGlider

-- Opposite edges are not neighbours.
def corners := board "#......#\n........\n........\n........\n........\n........\n........\n#......#"
#guard corners.neighbours 0 0 == 0
#guard corners.step.population == 0

#guard board "#\r\n#\r\n" == board "#\n#"
-- Starting and advancing the compiled author view has a native IO reference.
#eval show IO Unit from do
  for seed in #["bad", "#########", "#\n..", ""] do
    let session ← Lean.Vir.RuntimeM.run (lifeView seed).start
    unless session.initial.error.isSome && session.initial.html.isEmpty do
      throw <| IO.userError "invalid seed created a model"
  let a ← Lean.Vir.RuntimeM.run (lifeView "...\n###\n...").start
  let b ← Lean.Vir.RuntimeM.run (lifeView ".##.\n.##.").start
  let mut expected : State := { board := board "...\n###\n..." }
  for i in [:140] do
    expected := expected.step
    let frame ← Lean.Vir.RuntimeM.run a.advance
    unless frame.html == (renderState expected).asString && frame.label == s!"Generation {i + 1}" do
      throw <| IO.userError "automaton frame differs from pure transition"
    unless frame.html.utf8ByteSize < 65536 do throw <| IO.userError "frame budget exceeded"
  let still ← Lean.Vir.RuntimeM.run b.advance
  unless still.html == (renderState { generation := 1, board := board ".##.\n.##." }).asString do
    throw <| IO.userError "independent session changed"
  let boolean : VersoLeanRun.Automaton Bool := { initial := true, step := Bool.not }
  let session ← Lean.Vir.RuntimeM.run (boolean.view fun b => .text true (toString b)).start
  unless session.initial.html == "true" do throw <| IO.userError "wrong initial Bool state"
  unless (← Lean.Vir.RuntimeM.run session.advance).html == "false" do
    throw <| IO.userError "wrong next Bool state"
