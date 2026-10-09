module
public import Vir.Resources.Assets

public def LeanRunGate.resources : Vir.Resources.Bundle :=
  (include_vir_assets (modules := #[LeanRunGate.Chapter])).programs[0]!
