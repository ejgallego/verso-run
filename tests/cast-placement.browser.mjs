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
const frame = () => new Promise(resolve => setTimeout(resolve, 0));
window.checkPlacement = async () => {
  const requests = [], workers = [];
  let version = 1;
  const uri = "file:///Demo.lean";
  let reference = Object.freeze({ __rpcref: "native-reference" });
  const [wasmBytes, irPackage, documentJson, contracts] = await Promise.all([
    fetch("runtime.wasm").then(r => r.arrayBuffer()).then(b => new Uint8Array(b)),
    fetch("view.irpkg").then(r => r.arrayBuffer()).then(b => new Uint8Array(b)),
    fetch("document.json").then(r => r.text()), fetch("contracts.json").then(r => r.json()),
  ]);
  const runtime = await createVirRuntime({ wasmBytes, irPackageSet: [irPackage],
    hostBindings: createBrowserHostBindings({ reactHostBindings: createBrowserReactHostBindings }) });
  globalThis.castPlacementView = runtime.call("VersoLeanRun.Cast.View");
  globalThis.castFixture = { selections: [], inputs: [] };
  let controls;
  peer.session = { call(method, params, options) {
    if (method === "Lean.Vir.Infoview.readAsset") return Promise.resolve({ dataBase64: "AA==" });
    let resolve, reject;
    const promise = new Promise((accept, fail) => { resolve = accept; reject = fail; });
    const contract = contracts.find(row => row.description.declaration === params?.declaration);
    const reply = method === "VersoCast.Manual.Preview.Server.document" ?
      { uri, version, snapshotRef: reference, documentJson, hasErrors: false } :
      { uri, version, callable: contract?.description.callable, expectedExport: contract?.expectedExport, packageBase64: "AA==" };
    if (method.endsWith(".program")) check(params.snapshotRef === reference, "RPC retains exact captured native reference");
    requests.push({ method, reply, reject, signal: options.abortSignal, resolve: () => resolve(reply) });
    return promise;
  } };
  globalThis.Worker = class {
    constructor() { workers.push(this); }
    postMessage(data) {
      this.message = data;
      check(contracts.some(row => row.expectedExport === data.programRequest.expectedExport), "independently supplied contract reaches worker");
      check(data.programRequest.wasmBytes instanceof Uint8Array &&
        !Object.hasOwn(data.programRequest, "snapshotRef") && !Object.hasOwn(data.programRequest, "session"),
        "only ordinary bytes/metadata cross the worker boundary");
      queueMicrotask(() => this.onmessage({ data: { requestId: data.requestId, state: "running" } }));
    }
    reply(result) { this.onmessage({ data: { requestId: this.message.requestId, state: "success", result } }); }
    terminate() { this.terminated = true; }
  };
  let caught;
  let boundaryKey = 0;
  class Boundary extends React.Component {
    state = { failed: false };
    static getDerivedStateFromError() { return { failed: true }; }
    componentDidCatch(error) { caught = error; }
    render() { return this.state.failed ? "failed" : this.props.children; }
  }
  const root = createRoot(document.getElementById("app"), { onCaughtError() {} });
  const props = { wasmPath: ".vir/infoview.wasm", runRuntimeManifest: {} };
  const render = () => root.render(React.createElement(React.StrictMode, null,
    React.createElement(Boundary, { key: boundaryKey }, React.createElement(Widget, props))));
  const placements = () => [...document.querySelectorAll('[data-lean-run-context="infoview"]')];
  const submit = i => placements()[i].querySelector("form").requestSubmit();
  const last = () => requests.at(-1);
  try {
    await act(render);
    check(requests.filter(request => !request.signal.aborted).length === 1, "one active document request in StrictMode");
    await act(() => last().resolve());
    check(placements().length === 2 && !placements()[0].querySelector('button').disabled, "native controls admitted");
    const selected = globalThis.castFixture.selections.at(-1);
    const propsOf = element => {
      const pending = [root._internalRoot.current];
      while (pending.length) {
        let fiber = pending.pop();
        if (fiber.stateNode === element) {
          while (fiber && fiber.type?.name !== "RunPlacement") fiber = fiber.return;
          check(fiber, "native placement fiber exists");
          return fiber.memoizedProps;
        }
        if (fiber.child) pending.push(fiber.child);
        if (fiber.sibling) pending.push(fiber.sibling);
      }
      throw Error("committed placement fiber missing");
    };
    const captured = propsOf(placements()[0]).page;
    const retiredFatal = globalThis.castFixture.inputs.at(-1).onFatal;
    check(captured.signal === selected.signal && captured.session === selected.session && captured.snapshotRef === reference,
      "actual decoded Lean snapshot retains exact caller signal/session/reference");
    controls = propsOf(placements()[0]).controlsHtml;
    const unbound = document.createElement("div");
    unbound.className = "lean-run";
    unbound.dataset.leanRunContext = "infoview";
    unbound.dataset.experiment = JSON.stringify(contracts[0].description);
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
    await act(() => retiredFatal(Error("retired failure")));
    check(!caught && !workers[3].terminated, "retired native fatal handler cannot target a new owner");
    const liveFailure = Error("live native preview failure");
    await act(() => {
      const returned = globalThis.castFixture.inputs.at(-1).onFatal(liveFailure);
      check(returned === undefined && !caught, "native fatal callback returns normally before boundary handling");
    });
    check(caught === liveFailure && workers[3].terminated, "native boundary retains the live Error and stops its workers");

    boundaryKey++;
    caught = undefined;
    await act(render);
    await act(() => last().resolve());
    const debug = () => document.querySelector('[data-cast-preview-shell] input[type=checkbox]');
    await act(() => debug().click());
    const retained = placements()[0];
    const refreshPage = async () => act(() => {
      peer.notify("$/lean/fileProgress", { textDocument: { uri }, processing: [{}] });
      peer.notify("$/lean/fileProgress", { textDocument: { uri }, processing: [] });
    });
    await refreshPage();
    const obsolete = last();
    check(placements().every(p => p.querySelector('button').disabled), "batched reprocessing retires execution before replacement");
    await act(() => {
      version++;
      reference = Object.freeze({ __rpcref: "latest-reference" });
      peer.notify("textDocument/didChange", { textDocument: { uri, version }, contentChanges: [{ text: "newer" }] });
    });
    await act(() => peer.notify("$/lean/fileProgress", { textDocument: { uri }, processing: [] }));
    await act(() => last().resolve());
    let staleReads = 0;
    Object.defineProperty(obsolete.reply, "documentJson", { get() { staleReads++; throw Error("stale decode entered"); } });
    await act(() => obsolete.resolve());
    check(obsolete.signal.aborted && staleReads === 0 && !caught, "retired document reply is dropped before decoding");
    check(propsOf(placements()[0]).page.snapshotRef === reference && debug().checked,
      "newest provenance and retained debug state survive late reply");

    await refreshPage();
    last().reply.documentJson = "invalid JSON";
    await act(() => last().resolve());
    check(!caught && document.querySelector('[role=status]').textContent.includes("Invalid manual preview") &&
      placements()[0] === retained && placements()[0].querySelector('button').disabled,
      "parse failure is operational and retains disabled last-good DOM");
    await refreshPage();
    await act(() => last().reject(Error("operational RPC failure")));
    check(!caught && document.querySelector('[role=status]').textContent.includes("Could not load"),
      "RPC rejection is operational, separate from fatal forwarding");
    await refreshPage();
    last().reply.hasErrors = true;
    await act(() => last().resolve());
    check(!caught && propsOf(placements()[0]).page.hasErrors && placements()[0].querySelector('button').disabled,
      "recovered checked prose is visible without whole-page execution admission");
    await refreshPage();
    await act(() => last().resolve());
    check(debug().checked && !placements()[0].querySelector('button').disabled, "error recovery restores fresh explicit execution");
    await act(() => submit(0));
    await act(() => last().resolve());
    await act(frame);
    check(workers.length === 5, "a new native owner can run after boundary remount");
    await act(() => {
      runtime.dispose();
      globalThis.castFixture.unhealthy = true;
      render();
    });
    check(caught?.message === "Lean view unavailable" && workers[4].terminated,
      "native effect cleanup stops workers after actual View runtime disposal and controlled shell failure");
  } finally { await act(() => root.unmount()); runtime.dispose(); }
  check(peer.subscriptions === 0, "editor subscriptions released");
  return "actual Lean preview: captured signal/session/ref, pending Stop/late reply, independent workers, edits and native failure cleanup PASS";
};
