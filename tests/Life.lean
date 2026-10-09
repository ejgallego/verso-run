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
#guard (simulate "bad").steps.isEmpty && (simulate "bad").initialError.isSome
#guard (simulate "#########").initialError.isSome
#guard (simulate "#\n..").initialError.isSome
#guard (simulate "").initialError.isSome
#guard (simulate ".#.\n..#\n###").steps.size == 12
-- UTF-8 byte length bounds UTF-16 code units, without a removed JSON envelope.
#guard (lifeView "########\n########\n########\n########\n########\n########\n########\n########").toPayload.frames.foldl
  (fun size frame => size + frame.label.utf8ByteSize + frame.html.utf8ByteSize +
    (frame.error.getD "").utf8ByteSize) 0 < 65536
