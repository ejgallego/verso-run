module
public import VersoLeanRun.Automaton
public section

namespace LeanRunSequence.Life
open VersoLeanRun Verso.Output Verso.Output.Html

def side : Nat := 8

/-- The finite board has dead cells outside its boundary; it does not wrap. -/
structure Board where
  cells : Array Bool := Array.replicate (side * side) false
  deriving BEq, Repr

def Board.alive (board : Board) (row col : Nat) : Bool :=
  row < side && col < side && board.cells[row * side + col]?.getD false

def Board.population (board : Board) : Nat :=
  board.cells.foldl (fun n live => if live then n + 1 else n) 0

def Board.neighbours (board : Board) (row col : Nat) : Nat := Id.run do
  let mut count := 0
  for dr in [:3] do
    for dc in [:3] do
      if dr == 1 && dc == 1 then continue
      if (dr == 0 && row == 0) || (dc == 0 && col == 0) then continue
      if board.alive (row + dr - 1) (col + dc - 1) then count := count + 1
  return count

/-- B3/S23: birth with three neighbours, survival with two or three.
Every new cell reads the old board, so updates are simultaneous. -/
def Board.step (board : Board) : Board :=
  { cells := (Array.range (side * side)).map fun i =>
      let row := i / side
      let col := i % side
      let n := board.neighbours row col
      n == 3 || (board.alive row col && n == 2) }

/-- Centre a rectangular text seed on the board. One final newline is allowed. -/
def parse (input : String) : Except String Board := do
  let rows := (input.replace "\r\n" "\n").splitOn "\n"
  let rows := if rows.getLast? == some "" then rows.dropLast else rows
  unless !rows.isEmpty && rows.length ≤ side do
    throw "Enter 1–8 rows using # for live cells and . for dead cells."
  let width := rows.head!.length
  unless width > 0 && width ≤ side do throw "Use 1–8 cells per row."
  let mut board : Board := {}
  for (line, row) in rows.zipIdx do
    unless line.length == width do throw "Each row must have the same width."
    for (cell, col) in line.toList.zipIdx do
      unless cell == '#' || cell == '.' do throw "Use only # and . in the seed."
      let index := (row + (side - rows.length) / 2) * side + col + (side - width) / 2
      board := { cells := board.cells.set! index (cell == '#') }
  return board

structure State where
  generation : Nat := 0
  board : Board := {}

def State.step (state : State) : State :=
  { generation := state.generation + 1, board := state.board.step }


private def livePath (board : Board) : String := Id.run do
  let mut path := ""
  for row in [:side] do
    for col in [:side] do
      if board.alive row col then
        path := path ++ s!"M{col * 16} {row * 16}h16v16h-16z"
  return path

private def gridPath : String := Id.run do
  let mut path := ""
  for i in [:side + 1] do
    path := path ++ s!"M{i * 16} 0V128M0 {i * 16}H128"
  return path

def renderState (state : State) : Html :=
  {{ <div style="padding:.5rem">
    <p style="margin:0 0 .5rem;font-weight:600">{{s!"Generation {state.generation} · {state.board.population} living cells"}}</p>
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" role="img"
         aria-label={{s!"Game of Life generation {state.generation}, {state.board.population} living cells"}}
         style="display:block;width:176px;height:176px;max-width:100%;background:#f3f6fa">
      <path class="life-cells" d={{livePath state.board}} fill="#285674"> " " </path>
      <path d={{gridPath}} fill="none" stroke="#ccd9e5" stroke-width=".5"> " " </path>
    </svg>
  </div> }}

-- ANCHOR: lifeView
public def lifeView (seed : String) : VersoLeanRun.AutomatonView :=
  match parse seed with
  | .error message => AutomatonView.error message
  | .ok board =>
    let machine : Automaton State := { initial := { board }, step := State.step }
    machine.view renderState (fun n => s!"Generation {n}")
-- ANCHOR_END: lifeView

end LeanRunSequence.Life
