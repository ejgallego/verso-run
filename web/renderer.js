import { ExperimentHost } from "./host.js";
import { ViewHost } from "./presenter.js";
import { validateInput, scalarKind } from "./contract.js";
const owners = new Set();
addEventListener("pagehide", event => {
  for (const host of owners) {
    // A cached page retains its controls and listeners when Back restores it.
    if (event.persisted) host.stop("idle");
    else host.dispose();
  }
  if (!event.persisted) owners.clear();
});
let instance = 0;
export function enhance(element) {
  if (element.dataset.enhanced) return;
  element.dataset.enhanced = "true";
  element.dataset.instance = `lean-run-${++instance}`;
  const description = JSON.parse(element.dataset.experiment);
  const form = element.querySelector("form");
  const input = form.querySelector("input, select, textarea");
  if (input.tagName === "TEXTAREA") input.value = description.initialInput;
  const run = form.querySelector('[type="submit"]');
  const stop = form.querySelector(".lean-run-stop");
  const status = element.querySelector(".lean-run-status");
  const output = element.querySelector(".lean-run-output");
  const preview = element.querySelector(".lean-run-preview");
  const sequenceElement = element.querySelector(".lean-run-sequence");
  let busy = false;
  const setState = (state, value = "") => {
    element.dataset.state = state;
    busy = ["loading", "running", "loading view"].includes(state);
    run.disabled = busy;
    stop.disabled = !busy;
    status.textContent = state === "idle" ? "Ready" :
      state === "success" && sequenceElement ? "Trace ready" :
      state[0].toUpperCase() + state.slice(1);
    output.textContent = value;
  };
  const pane = sequenceElement || preview;
  const view = pane ? new ViewHost(pane, sequenceElement ? "sequence" : "html", error => {
    setState("failed", `Could not display the view. Try Run again. ${error.message}`);
  }) : null;
  const clearResult = () => view?.clear();
  const host = new ExperimentHost(description, (state, value = "") => {
    clearResult();
    setState(state, state === "success" && view ? "" : value);
    if (state === "success" && view) {
      setState("loading view");
      void view.show(value).then(shown => {
        if (!shown) return;
        setState("success");
      });
    }
  });
  owners.add(host);
  run.disabled = false;
  form.addEventListener("submit", event => {
    event.preventDefault();
    if (busy) return;
    try { validateInput(scalarKind(description.form), input.value); }
    catch (error) {
      clearResult();
      setState("invalid input", error.message);
      return;
    }
    host.invoke(input.value).catch(() => {}); // Host owns all state/error reporting.
  });
  stop.addEventListener("click", () => host.stop());
  element.addEventListener("lean-run-stop", () => host.stop());
  element.addEventListener("lean-run-dispose", () => {
    host.dispose();
    owners.delete(host);
  });
  input.addEventListener("input", () => host.stop("idle"));
  if (input.tagName === "TEXTAREA") input.addEventListener("keydown", event => {
    if (event.key === "Enter" && (event.ctrlKey || event.metaKey)) {
      event.preventDefault();
      form.requestSubmit();
    }
  });
}
