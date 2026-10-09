module
set_option compiler.postponeCompile false

-- ANCHOR: flip
public def LeanRunTyped.Examples.flip (value : Bool) : Bool := !value
-- ANCHOR_END: flip

-- ANCHOR: increment
public def LeanRunTyped.Examples.increment (value : UInt64) : UInt64 := value + 1
-- ANCHOR_END: increment

-- ANCHOR: lines
public def LeanRunTyped.Examples.lines (text : String) : String :=
  String.intercalate "\n" <|
    (text.splitOn "\n").zipIdx.map fun (line, index) =>
      s!"{index + 1}. {line}"
-- ANCHOR_END: lines
