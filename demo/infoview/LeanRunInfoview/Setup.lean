module
public import VersoLeanRun.Cast
public import Vir.Resources.Runtime
public meta import VersoLeanRun.Cast

public def LeanRunInfoview.widgetProps : VersoLeanRun.Cast.Props :=
  VersoLeanRun.Cast.props Vir.Resources.Runtime.bundle
