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
    let session ← Lean.Vir.RuntimeM.run (lifeView seed)
    unless session.initial.error.isSome && session.initial.content.render.isEmpty do
      throw <| IO.userError "invalid seed created a model"
  let a ← Lean.Vir.RuntimeM.run (lifeView "...\n###\n...")
  let b ← Lean.Vir.RuntimeM.run (lifeView ".##.\n.##.")
  let mut expected : State := { board := board "...\n###\n..." }
  for i in [:140] do
    expected := expected.step
    let frame ← Lean.Vir.RuntimeM.run a.advance
    unless frame.content.render == (renderState expected).render && frame.label == s!"Generation {i + 1}" do
      throw <| IO.userError "automaton frame differs from pure transition"
    unless frame.content.render.utf8ByteSize < 65536 do throw <| IO.userError "frame budget exceeded"
  let still ← Lean.Vir.RuntimeM.run b.advance
  unless still.content.render == (renderState { generation := 1, board := board ".##.\n.##." }).render do
    throw <| IO.userError "independent session changed"
  let boolean : VersoLeanRun.Automaton Bool := { initial := true, step := Bool.not }
  let session ← Lean.Vir.RuntimeM.run (boolean.view fun b => .text (toString b))
  unless session.initial.content.render == "true" do throw <| IO.userError "wrong initial Bool state"
  unless (← Lean.Vir.RuntimeM.run session.advance).content.render == "false" do
    throw <| IO.userError "wrong next Bool state"
  let counter : VersoLeanRun.Automaton Nat := { initial := 10, step := (· + 1) }
  let live ← Lean.Vir.RuntimeM.run counter.view
  unless live.initial.content.render == "10" && live.initial.label == "0" do
    throw <| IO.userError "wrong initial text observation"
  for frame in (counter.trace 4).view.frames do
    -- The trace labels and text observations agree with the live session.
    if frame.label != "0" then
      let next ← Lean.Vir.RuntimeM.run live.advance
      unless next.label == frame.label && next.content.render == frame.content.render do
        throw <| IO.userError "trace and live observations disagree"
  let recorded : VersoLeanRun.Sequence Nat := {
    initial := { label := "A", content := 1 }
    steps := #[{ label := "B", content := 1, error := some "note" }, { label := "C", content := 2 }] }
  let replay ← Lean.Vir.RuntimeM.run (recorded.cycleView fun n => .text (toString n))
  let independent ← Lean.Vir.RuntimeM.run (recorded.cycleView fun n => .text (toString n))
  unless replay.initial.label == "A" do throw <| IO.userError "wrong replay initial"
  for label in #["B", "C", "A", "B", "C", "A"] do
    let next ← Lean.Vir.RuntimeM.run replay.advance
    unless next.label == label && next.error == (if label == "B" then some "note" else none) do
      throw <| IO.userError "replay lost order or error metadata"
  unless (← Lean.Vir.RuntimeM.run independent.advance).label == "B" do
    throw <| IO.userError "replay cursors are shared"
