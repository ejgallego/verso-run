module
public import Vir.Resources.Assets

public def LeanRunGate.resources : Vir.Resources.ResourceSet :=
  include_vir_assets (modules := #[LeanRunGate.Chapter])
