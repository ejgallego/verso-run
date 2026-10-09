module
public import Vir.Resources.Assets

public def LeanRunBlog.postResources : Vir.Resources.ResourceSet :=
  include_vir_assets (modules := #[LeanRunBlog.Post])
