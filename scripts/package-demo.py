"""Package a complete generated demo for HTTP hosting."""
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parent.parent
site = root / "_out/html-multi"
archive = root / "_out/verso-run-demo.zip"
if not (site / "lean-run/publication.json").is_file():
    raise SystemExit("Generate the demo with python3 scripts/build-demo-site.py first.")
with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as z:
    for path in sorted(site.rglob("*")):
        if path.is_file():
            z.write(path, Path("verso-run-demo") / path.relative_to(site))
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
print(archive)
