module
public import Vir.Resources.Assets
public def Consumer.slidesResources : Vir.Resources.ResourceSet :=
  include_vir_assets (modules := #[Consumer.Slides])
