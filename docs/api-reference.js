// Keep Verso's generated declarations, anchors and highlighting intact. The
// checked guide comes first; readers can open the full reference when needed.
document.addEventListener("DOMContentLoaded", () => {
  for (const content of document.querySelectorAll(".code-content")) {
    const code = [...content.children].filter(child => child.matches(".code-box"));
    if (!code.length) continue;
    const reference = document.createElement("details");
    reference.className = "api-declarations";
    const summary = document.createElement("summary");
    summary.textContent = "Declarations and implementation";
    reference.append(summary, ...code);
    content.append(reference);
    // Match the visual order in CSS, including keyboard and reading order.
    const imports = content.querySelector(":scope > .imports-list");
    if (imports) content.append(imports);
  }

  const revealTarget = () => {
    let id;
    try { id = decodeURIComponent(location.hash.slice(1)); }
    catch { return; }
    const target = document.getElementById(id);
    const reference = target?.closest(".api-declarations");
    if (reference) {
      reference.open = true;
      target.scrollIntoView();
    }
  };
  revealTarget();
  addEventListener("hashchange", revealTarget);
});
