import { enhance } from "./renderer.js";

addEventListener("DOMContentLoaded", () => {
  const forms = new Map();
  const visible = element => {
    const slide = element.closest(".slides section");
    if (slide && !slide.classList.contains("present")) return false;
    for (let ancestor = element; ancestor; ancestor = ancestor.parentElement) {
      if (!ancestor.classList.contains("fragment")) continue;
      const shown = ancestor.classList.contains("visible");
      if (ancestor.classList.contains("fade-out") ? shown : !shown) return false;
      if (ancestor.classList.contains("fade-in-then-out") &&
          !ancestor.classList.contains("current-fragment")) return false;
    }
    return true;
  };
  const attach = element => {
    const description = JSON.parse(element.dataset.experiment);
    if (description.collapsed) {
      const source = element.querySelector(".lean-run-source");
      if (source.tagName !== "DETAILS") {
        const details = document.createElement("details");
        details.className = "lean-run-source";
        const summary = document.createElement("summary");
        summary.textContent = "View Lean implementation";
        details.append(summary, ...source.childNodes);
        source.replaceWith(details);
      }
    }
    const owner = enhance(element);
    forms.set(element, owner);
    // Reveal also uses Enter, arrows, and Space. These guards share the placement's lifetime.
    element.addEventListener("keydown", event => event.stopPropagation(), { signal: owner.signal });
    element.addEventListener("submit", event => {
      if (!visible(element)) {
        event.preventDefault();
        event.stopImmediatePropagation();
      }
    }, { capture: true, signal: owner.signal });
  };
  const stopHidden = () => {
    for (const [element, owner] of forms) {
      const shown = visible(element);
      // Unvisited placements have no session to stop. Keep their initial Ready
      // state; entering a slide must not imply an earlier Run or cancellation.
      if (!shown && element.dataset.state && element.dataset.state !== "stopped") {
        owner.stop();
      }
      element.querySelector('[type="submit"]').disabled = !shown ||
        ["loading", "running"].includes(element.dataset.state);
    }
  };
  const refresh = () => {
    for (const [element, owner] of forms) {
      if (!element.isConnected) {
        owner.dispose();
        forms.delete(element);
      }
    }
    for (const element of document.querySelectorAll(".lean-run-slides")) {
      if (!forms.has(element)) attach(element);
    }
    stopHidden();
  };
  for (const name of ["ready", "slidechanged", "fragmentshown", "fragmenthidden"]) Reveal.on(name, stopHidden);
  new MutationObserver(refresh).observe(document.querySelector(".reveal .slides"),
    { childList: true, subtree: true });
  refresh();
});
