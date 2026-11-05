import Consumer.Model
import VersoLeanRun.ResultPresenter

def Consumer.presenter : VersoLeanRun.ResultPresenter := {
  resultType := resultType% Consumer.Packet
  workerModule := { path := "lean-run/packet/normalize.js", bytes := (include_str "web/normalize.js").toUTF8 }
  rendererModule := { path := "lean-run/packet/render.js", bytes := (include_str "web/render.js").toUTF8 }
}
