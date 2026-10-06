import { ExperimentHost } from "./host.js";
import { validateInput } from "./contract.js";
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
  const input = form.querySelector("input");
  const run = form.querySelector('[type="submit"]');
  const stop = form.querySelector(".lean-run-stop");
  const status = element.querySelector(".lean-run-status");
  const output = element.querySelector(".lean-run-output");
  let busy = false;
  const host = new ExperimentHost(description, (state, value = "") => {
    element.dataset.state = state;
    busy = state === "loading" || state === "running";
    run.disabled = busy;
    stop.disabled = !busy;
    status.textContent = state === "idle" ? "Ready" : state[0].toUpperCase() + state.slice(1);
    output.textContent = value;
  });
  owners.add(host);
  run.disabled = false;
  form.addEventListener("submit", event => {
    event.preventDefault();
    if (busy) return;
    try { validateInput(description.shape, input.value); }
    catch (error) {
      element.dataset.state = "invalid input";
      status.textContent = "Invalid input";
      output.textContent = error.message;
      return;
    }
    host.invoke(input.value).catch(() => {}); // Host owns all state/error reporting.
  });
  stop.addEventListener("click", () => host.stop());
  input.addEventListener("input", () => host.stop("idle"));
}
