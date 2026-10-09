module
public import Vir.Resources.Assets

public def LeanRunBlog.pageResources : Vir.Resources.ResourceSet :=
  include_vir_assets (modules := #[LeanRunBlog.Page])
