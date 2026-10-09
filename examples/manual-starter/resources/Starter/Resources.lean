module
public import Vir.Resources.Assets

public def Starter.resources : Vir.Resources.Bundle :=
  (include_vir_assets (modules := #[Starter.Chapter])).programs[0]!
