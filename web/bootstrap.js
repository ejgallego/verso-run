addEventListener("DOMContentLoaded", async () => {
  for (const element of document.querySelectorAll(".lean-run")) {
    const { enhance } = await import(new URL("lean-run/renderer.js", document.baseURI));
    enhance(element);
  }
});
