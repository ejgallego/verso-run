addEventListener("DOMContentLoaded", async () => {
  for (const element of document.querySelectorAll(".lean-run")) {
    const explicitRenderer = element.dataset.leanRunRenderer;
    const renderer = explicitRenderer ?? "lean-run/renderer.js";
    const { enhance } = await import(new URL(renderer,
      explicitRenderer ? location.href : document.baseURI));
    enhance(element);
  }
});
