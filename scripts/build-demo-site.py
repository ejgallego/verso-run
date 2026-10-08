"""Generate both qualified genres and a format landing page, preserving Manual URLs."""
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parent.parent
subprocess.run(["lake", "exe", "lean-run-demo", "--with-html-single", "--with-tex", "--depth", "2"],
               cwd=root, check=True)
site = root / "_out/html-multi"
subprocess.run(["lake", "exe", "lean-run-blog-demo", "--output", str(site / "blog")],
               cwd=root, check=True)
# The root landing uses the Blog home's own relative asset/link convention.
# Existing Manual chapters and their root execution inventory keep their URLs.
home = (site / "blog/index.html").read_text()
assert len(re.findall(r'<base href="[^"]*">', home)) == 1
(site / "index.html").write_text(re.sub(r'<base href="[^"]*">',
    '<base href="blog/">', home, count=1))
print(f"Combined demo: {site}")
