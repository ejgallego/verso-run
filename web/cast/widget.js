import React from "react";
import css from "../lean-run.css";
import VirShell from "__VIR_SHELL__";
import workerSource from "__RUN_WORKER__";
import katex from "__KATEX__";
import mathCss from "__KATEX_CSS__";
import { createMathComponent } from "verso-cast/katex";
import { PageHost } from "./page.js";
import { bindBackend, enhance } from "../renderer.js";
import { editorBackend, decodeBase64 } from "./backend.js";

const RuntimeContext = React.createContext(null);
const MathFormula = createMathComponent(katex);

export function RunPlacement({ page, matchesSelection, description, controlsHtml }) {
  const runtime = React.useContext(RuntimeContext);
  const slot = React.useRef(null);
  React.useLayoutEffect(() => {
    const element = slot.current;
    element.innerHTML = controlsHtml;
    element.dataset.experiment = description;
    let unbind;
    const disable = () => {
      // Unbind before disposal so the global observer cannot reattach a stale owner.
      unbind?.();
      for (const button of element.querySelectorAll("button")) button.disabled = true;
      const status = element.querySelector(".lean-run-status");
      const currentError = matchesSelection && page.hasErrors && page.signal && !page.signal.aborted;
      if (status) status.textContent = currentError ?
        "Fix Lean errors in this page before running." :
        "Waiting for a current checked page…";
    };
    if (matchesSelection && page.signal && !page.signal.aborted && !page.hasErrors) {
      const backend = editorBackend(page, runtime, () => {
        const url = URL.createObjectURL(new Blob([workerSource], { type: "text/javascript" }));
        let worker;
        try { worker = new Worker(url, { type: "module" }); }
        catch (error) { URL.revokeObjectURL(url); throw error; }
        const terminate = worker.terminate.bind(worker);
        worker.terminate = () => { try { terminate(); } finally { URL.revokeObjectURL(url); } };
        return worker;
      });
      try {
        unbind = bindBackend(element, backend);
        page.signal.addEventListener("abort", disable, { once: true });
        enhance(element);
        if (page.signal.aborted) disable();
      } catch (error) {
        page.signal.removeEventListener("abort", disable);
        disable();
        throw error;
      }
    } else disable();
    return () => {
      page.signal?.removeEventListener("abort", disable);
      disable();
      element.replaceChildren();
    };
  }, [runtime, matchesSelection, page.signal, page.session, page.snapshotRef, page.hasErrors,
    page.uri, page.version, description, controlsHtml]);
  return React.createElement("div", { ref: slot, className: "lean-run",
    "data-lean-run-context": "infoview" });
}

export default function Widget(props) {
  const manifestJson = JSON.stringify(props.runRuntimeManifest);
  const runtime = React.useMemo(() => ({
    manifest: JSON.parse(manifestJson), contentId: __RUN_RUNTIME_CONTENT_ID__,
    async bytes(session, signal) {
      const reply = await session.call("Lean.Vir.Infoview.readAsset", { path: props.wasmPath }, { abortSignal: signal });
      if (signal.aborted) throw signal.reason;
      return decodeBase64(reply.dataBase64);
    },
  }), [manifestJson, props.wasmPath]);
  return React.createElement(RuntimeContext.Provider, { value: runtime },
    React.createElement("style", null, css),
    React.createElement("style", null, mathCss),
    React.createElement(VirShell, { ...props, pageHost: PageHost, runPlacement: RunPlacement,
      mathComponent: MathFormula }));
}
