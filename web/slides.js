import { enhance } from "./renderer.js";

addEventListener("DOMContentLoaded", () => {
  const forms = new Set();
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
    forms.add(element);
    // Reveal restores its saved HTML when leaving scroll view. Copied attributes
    // do not carry the original controls' listeners or worker ownership.
    delete element.dataset.enhanced;
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
    // Reveal also uses Enter, arrows, and Space. The form owns keys while focused.
    element.addEventListener("keydown", event => event.stopPropagation());
    element.addEventListener("submit", event => {
      if (!visible(element)) {
        event.preventDefault();
        event.stopImmediatePropagation();
      }
    }, true);
    enhance(element);
  };
  const stopHidden = () => {
    for (const element of forms) {
      const shown = visible(element);
      if (!shown && element.dataset.state !== "stopped") {
        element.dispatchEvent(new Event("lean-run-stop"));
      }
      element.querySelector('[type="submit"]').disabled = !shown ||
        ["loading", "running"].includes(element.dataset.state);
    }
  };
  const refresh = () => {
    for (const element of forms) {
      if (!element.isConnected) {
        element.dispatchEvent(new Event("lean-run-dispose"));
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
