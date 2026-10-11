"""Build Verso's literate HTML with source freshness for the pinned module system."""
import hashlib
from pathlib import Path
import subprocess
import tomllib

root = Path(__file__).resolve().parent.parent
sources = root / 'src/views'
build = root / '.lake/build'
stamp = build / 'api-reference-inputs.sha256'
files = sorted(sources.rglob('*.lean'))
config_file = root / 'literate.toml'
config = tomllib.loads(config_file.read_text())
inputs = files + [config_file] + [root / name for name in
    config.get('extra_css', []) + config.get('extra_js', [])]
digest = hashlib.sha256()
for source in inputs:
    digest.update(str(source.relative_to(root)).encode() + b'\0')
    digest.update(source.read_bytes() + b'\0')
signature = digest.hexdigest()

# At the pinned Verso revision, module:literate tracks only the public olean.
# A module docstring can change without changing that artifact. Invalidate
# only this library's extracted JSON when its source changes; Verso still owns
# planning, extraction and rendering. Refresh all four modules so imported
# declaration hovers also reflect changed documentation. The pinned HTML facet
# also omits extra asset contents from its trace, so track configuration/assets
# here and invalidate the rendered-site trace when these inputs change.
if not stamp.is_file() or stamp.read_text().strip() != signature:
    for source in files:
        extracted = build / 'literate' / source.relative_to(sources).with_suffix('.json')
        extracted.unlink(missing_ok=True)
    (build / 'literate-html.trace').unlink(missing_ok=True)

subprocess.run(['lake', 'build', ':literateHtml'], cwd=root, check=True)
stamp.write_text(signature + '\n')
