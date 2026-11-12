import React from "react";
import { createRoot } from "react-dom/client";
import Widget from "../web/cast/widget.js";
import { peer } from "@cast-test/infoview-peer";
import { createVirRuntime } from "lean-vir";
import { createBrowserHostBindings } from "lean-vir/host-bindings";
import { createBrowserReactHostBindings } from "lean-vir/react-host-bindings";

globalThis.IS_REACT_ACT_ENVIRONMENT = true;
const check = (value, message) => { if (!value) throw Error(message); };
const act = action => React.act(async () => { await action(); });
window.checkMath = async () => {
  const [wasmBytes, irPackage, documentJson] = await Promise.all([
    fetch("runtime.wasm").then(r => r.arrayBuffer()).then(b => new Uint8Array(b)),
    fetch("view.irpkg").then(r => r.arrayBuffer()).then(b => new Uint8Array(b)),
    fetch("document.json").then(r => r.text()),
  ]);
  const runtime = await createVirRuntime({ wasmBytes, irPackageSet: [irPackage],
    hostBindings: createBrowserHostBindings({ reactHostBindings: createBrowserReactHostBindings }) });
  globalThis.castMathView = runtime.call("VersoLeanRun.Cast.View");
  peer.session = { call(method) {
    check(method === "VersoCast.Manual.Preview.Server.document", "only document acquisition expected");
    return Promise.resolve({ uri: "file:///CastMathDoc.lean", version: 1, documentJson,
      snapshotRef: Object.freeze({ __rpcref: "controlled-page" }), hasErrors: false });
  } };
  const root = createRoot(document.getElementById("app"));
  window.disposeMath = async () => {
    await act(() => root.unmount());
    runtime.dispose();
  };
  try {
    await act(() => root.render(React.createElement(React.StrictMode, null,
      React.createElement(Widget, { wasmPath: "unused", runRuntimeManifest: {} }))));
    await act(() => new Promise(resolve => setTimeout(resolve, 50)));
    const inline = document.querySelector('[data-verso-math-mode="inline"]');
    check(inline?.querySelector(".katex"), "actual Lean adapter injects the public KaTeX component");
    check(inline.querySelector("annotation").textContent === String.raw`a + x \alpha`, "TeX source retained");
    check(inline.textContent.includes("α"), "alpha is rendered");
    check(document.querySelector('[data-verso-math-mode="display"] .katex-display'), "display math rendered");
    check(document.querySelector(".katex-error")?.textContent === "{", "invalid TeX stays visible");
    await document.fonts.ready;
    check([...document.fonts].some(font => font.family.includes("KaTeX") && font.status === "loaded"),
      "bundled fonts load without a remote font provider");
    return "actual Lean adapter: inline/display math, malformed recovery, source and embedded fonts PASS";
  } catch (error) {
    await window.disposeMath();
    throw error;
  }
};
