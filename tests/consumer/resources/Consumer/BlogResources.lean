module
public import Vir.Resources.Assets
public def Consumer.blogResources : Vir.Resources.ResourceSet :=
  include_vir_assets (modules := #[Consumer.Blog])
