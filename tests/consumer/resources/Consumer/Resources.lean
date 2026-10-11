module
public import Vir.Resources.Assets

public def Consumer.resources : Vir.Resources.ResourceSet :=
  include_vir_assets (modules := #[Consumer.Chapter])
