"""Generate the three genres and their landing page, preserving Manual URLs."""
from pathlib import Path
import json
import re
import subprocess

root = Path(__file__).resolve().parent.parent
subprocess.run(["lake", "exe", "lean-run-demo", "--with-html-single", "--with-tex", "--depth", "2"],
               cwd=root, check=True)
site = root / "_out/html-multi"
subprocess.run(["lake", "exe", "lean-run-blog-demo", "--output", str(site / "blog")],
               cwd=root, check=True)
subprocess.run(["lake", "exe", "lean-run-slides-demo", "--output", str(site / "slides")],
               cwd=root, check=True)
# The root landing uses the Blog home's own relative asset/link convention.
# Existing Manual chapters and their root execution inventory keep their URLs.
home = (site / "blog/index.html").read_text()
assert len(re.findall(r'<base href="[^"]*">', home)) == 1
(site / "index.html").write_text(re.sub(r'<base href="[^"]*">',
    '<base href="blog/">', home, count=1))
manifest = json.loads((root / "lake-manifest.json").read_text())
identity = {
    "source": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
    "dirty": bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=root, text=True).strip()),
    "dependencies": {p["name"]: p["rev"] for p in manifest["packages"]},
    "runtime": json.loads((root / ".lake/packages/lean_vir/vir-resources/runtime.json").read_text())["contentId"],
}
(site / "verso-run-build.json").write_text(json.dumps(identity, indent=2) + "\n")
print(f"Combined demo: {site}")
