import React from "react";
import { createRoot } from "react-dom/client";
import Widget from "../web/cast/widget.js";
import { peer } from "@cast-test/infoview-peer";

globalThis.IS_REACT_ACT_ENVIRONMENT = true;
const check = (value, message) => { if (!value) throw Error(message); };
const act = action => React.act(async () => { await action(); });
const frame = () => new Promise(resolve => setTimeout(resolve, 0));
window.checkPlacement = async () => {
  const requests = [], workers = [];
  let version = 1;
  const uri = "file:///Demo.lean";
  let reference = Object.freeze({ __rpcref: "native-reference" });
  const expectedExport = { independent: "scalar-contract" };
  const controls = '<div class="lean-run-console"><form><input value="21"><button type="submit" disabled>Run</button><button type="button" class="lean-run-stop" disabled>Stop</button></form><p class="lean-run-status"></p><pre class="lean-run-output"></pre></div>';
  globalThis.castFixture = { description: JSON.stringify({ program: "Demo", declaration: "double",
    callable: "double", form: "nat", initialInput: "21" }), controls };
  peer.session = { call(method, params, options) {
    if (method === "Lean.Vir.Infoview.readAsset") return Promise.resolve({ dataBase64: "AA==" });
    let resolve;
    const promise = new Promise(accept => { resolve = accept; });
    const reply = method === "VersoCast.Manual.Preview.Server.document" ?
      { uri, version, snapshotRef: reference, documentJson: "page", hasErrors: false } :
      { uri, version, callable: "double", expectedExport, packageBase64: "AA==" };
    if (method.endsWith(".program")) check(params.snapshotRef === reference, "RPC retains exact captured native reference");
    requests.push({ method, signal: options.abortSignal, resolve: () => resolve(reply) });
    return promise;
  } };
  globalThis.Worker = class {
    constructor() { workers.push(this); }
    postMessage(data) {
      this.message = data;
      check(data.programRequest.expectedExport === expectedExport, "independently supplied contract reaches worker");
      check(data.programRequest.wasmBytes instanceof Uint8Array &&
        !Object.hasOwn(data.programRequest, "snapshotRef") && !Object.hasOwn(data.programRequest, "session"),
        "only ordinary bytes/metadata cross the worker boundary");
      queueMicrotask(() => this.onmessage({ data: { requestId: data.requestId, state: "running" } }));
    }
    reply(result) { this.onmessage({ data: { requestId: this.message.requestId, state: "success", result } }); }
    terminate() { this.terminated = true; }
  };
  let caught;
  class Boundary extends React.Component {
    state = { failed: false };
    static getDerivedStateFromError() { return { failed: true }; }
    componentDidCatch(error) { caught = error; }
    render() { return this.state.failed ? "failed" : this.props.children; }
  }
  const root = createRoot(document.getElementById("app"), { onCaughtError() {} });
  const props = { wasmPath: ".vir/infoview.wasm", runRuntimeManifest: {} };
  const render = () => root.render(React.createElement(React.StrictMode, null,
    React.createElement(Boundary, null, React.createElement(Widget, props))));
  const placements = () => [...document.querySelectorAll('[data-lean-run-context="infoview"]')];
  const submit = i => placements()[i].querySelector("form").requestSubmit();
  const last = () => requests.at(-1);
  try {
    await act(render);
    check(requests.length === 1, "one selected document in StrictMode");
    await act(() => last().resolve());
    check(placements().length === 2 && !placements()[0].querySelector('button').disabled, "native controls admitted");
    const unbound = document.createElement("div");
    unbound.className = "lean-run";
    unbound.dataset.leanRunContext = "infoview";
    unbound.dataset.experiment = globalThis.castFixture.description;
    unbound.innerHTML = controls;
    document.body.appendChild(unbound);
    await act(frame);
    check(!unbound.dataset.enhanced && unbound.querySelector('button').disabled,
      "active reconciliation cannot attach a site backend before native binding");
    unbound.remove();
    await act(() => submit(0));
    const abandoned = last();
    await act(() => placements()[0].querySelector('.lean-run-stop').click());
    check(abandoned.signal.aborted && workers.length === 0, "Stop cancels pending package RPC before worker creation");
    await act(() => abandoned.resolve());
    check(workers.length === 0, "late stopped package creates no worker");
    await act(() => submit(0));
    await act(() => last().resolve());
    await act(frame);
    check(workers.length === 1, "retry starts a fresh independent worker");
    await act(() => submit(1));
    await act(() => last().resolve());
    await act(frame);
    check(workers.length === 2, "repeated placements own separate workers");
    await act(() => placements()[0].querySelector('.lean-run-stop').click());
    check(workers[0].terminated && !workers[1].terminated, "per-placement Stop leaves its peer running");
    await act(() => workers[1].reply("42"));
    check(placements()[1].querySelector('.lean-run-output').textContent === "42", "shared host presents scalar result");
    const count = requests.length;
    props.runRuntimeManifest = {}; // identical metadata may arrive in a new native envelope
    await act(() => peer.notify("stopped", undefined)); // real cursor status clear
    await act(render);
    check(requests.length === count, "stable cursor-like render retains request and placement state");
    await act(() => {
      version++;
      peer.notify("textDocument/didChange", { textDocument: { uri, version }, contentChanges: [{ text: "edit" }] });
      check(workers[1].terminated, "edit terminates worker synchronously before a replacement render");
    });
    check(placements().every(p => p.querySelector('button').disabled), "retained old prose has disabled controls");
    await act(() => peer.notify("$/lean/fileProgress", { textDocument: { uri }, processing: [] }));
    await act(() => last().resolve());
    await act(() => submit(0));
    await act(() => last().resolve());
    await act(frame);
    check(workers.length === 3, "edited selection can run explicitly");
    await act(() => {
      peer.notify("textDocument/didClose", { textDocument: { uri } });
      check(workers[2].terminated, "document close stops the native worker synchronously");
    });
    check(placements().every(p => p.querySelector('button').disabled), "closed page keeps no executable controls");
    reference = Object.freeze({ __rpcref: "new-session-reference" });
    peer.session = { ...peer.session };
    await act(() => peer.notify("stopped", undefined));
    await act(() => last().resolve());
    await act(() => submit(0));
    await act(() => last().resolve());
    await act(frame);
    check(workers.length === 4, "cleared stop status permits a fresh session selection");
    globalThis.castFixture.unhealthy = true;
    await act(render);
    check(caught?.message === "Lean view unavailable" && workers[3].terminated,
      "native effect cleanup terminates execution when the Lean view fails");
  } finally { await act(() => root.unmount()); }
  check(peer.subscriptions === 0, "editor subscriptions released");
  return "captured RPC ref, pending Stop/late reply, independent workers, edits and failing-Lean cleanup PASS";
};
