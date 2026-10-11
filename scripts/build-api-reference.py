"""Build Verso's literate HTML with source freshness for the pinned module system."""
import hashlib
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent.parent
sources = root / 'src/views'
build = root / '.lake/build'
stamp = build / 'api-reference-sources.sha256'
files = sorted(sources.rglob('*.lean'))
digest = hashlib.sha256()
for source in files:
    digest.update(str(source.relative_to(sources)).encode() + b'\0')
    digest.update(source.read_bytes() + b'\0')
signature = digest.hexdigest()

# At the pinned Verso revision, module:literate tracks only the public olean.
# A module docstring can change without changing that artifact. Invalidate
# only this library's extracted JSON when its source changes; Verso still owns
# planning, extraction and rendering. Refresh all four modules so imported
# declaration hovers also reflect changed documentation.
if not stamp.is_file() or stamp.read_text().strip() != signature:
    for source in files:
        extracted = build / 'literate' / source.relative_to(sources).with_suffix('.json')
        extracted.unlink(missing_ok=True)

subprocess.run(['lake', 'build', ':literateHtml'], cwd=root, check=True)
stamp.write_text(signature + '\n')
