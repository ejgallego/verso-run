module
public import Vir.Resources.Assets

public def Starter.resources : Vir.Resources.ResourceSet :=
  include_vir_assets (modules := #[Starter.Chapter])
