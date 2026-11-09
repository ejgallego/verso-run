"""Replay Cast's exact native regressions against this consumer's editor host.

Uses a controlled Infoview peer, real locked React, and the selected Cast helper.
Also requires the regressions to reject the previous host and helper separately.
This does not start VS Code, LSP, Wasm, or a Run worker.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'tests'))
from harness import serve_directory

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--cast-source', type=Path, required=True)
parser.add_argument('--output', type=Path, default=ROOT / '_out/cast-preview-6bee7e7')
args = parser.parse_args()
output = args.output.resolve()
assert output.is_relative_to(ROOT / '_out')
report_path = output / 'results.json'
report = json.loads(report_path.read_text())
assert report['castRevision'] == '6bee7e7e06546cef75ee873bbe7e6252151e0432'
assert report['editorSmoke']['status'] == 'prepared'
project = Path(report['project'])
digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
for name, expected in report['sourceFiles'].items():
    assert digest(project / 'cast-source' / name) == expected
host = project / 'EditorHost.mjs'
assert digest(host) == report['editorSmoke']['fixtureSha256']['EditorHost.mjs']
assert host.read_bytes() == (ROOT / 'experiments/cast-compatibility/EditorHost.mjs').read_bytes()
manifest = json.loads((project / 'cast-source/package.json').read_text())
helper = (project / 'cast-source' / manifest['exports']['./preview']).resolve()
controls = project / 'native-preview/controls'
controls.mkdir(parents=True, exist_ok=True)
old_host = controls / 'host-9701d6f.mjs'
old_host.write_bytes(subprocess.check_output([
    'git', 'show', '07adbfcdfdda0d48c07d9396d81ebd6995355215:experiments/cast-compatibility/EditorHost.mjs'], cwd=ROOT))
old_helper = controls / 'helper-9701d6f.mjs'
old_helper.write_bytes(subprocess.check_output([
    'git', 'show', '9701d6f1794c20a6ad8966bd92f6ebba12872f62:js/preview.mjs'], cwd=args.cast_source))
cases = [
    ('current', host, helper, ['checkPreview', 'checkEditorOwner'], None),
    ('old-host', old_host, helper, ['checkEditorOwner'], 'batched busy/finished replaces a same-version selection exactly once'),
    ('old-helper', host, old_helper, ['checkPreview'], 'decoder-only replacement rejects the old reply'),
]
results = []
with sync_playwright() as playwright:
    browser = playwright.chromium.launch(headless=True, executable_path=shutil.which('google-chrome'))
    try:
        for name, selected_host, selected_helper, checks, expected_failure in cases:
            directory = project / 'native-preview' / name
            log_path = output / f'client-{name}-bundle.log'
            with log_path.open('w') as log:
                subprocess.run(['node', str(ROOT / 'experiments/cast-compatibility/bundle-client.mjs'),
                                str(project), str(selected_host), str(selected_helper), str(directory)],
                               cwd=project, stdout=log, stderr=subprocess.STDOUT, check=True)
            errors = []
            page = browser.new_page()
            page.on('pageerror', lambda error: errors.append(str(error)))
            page.on('console', lambda message: errors.append(message.text) if message.type == 'error' else None)
            try:
                with serve_directory(directory) as url:
                    page.goto(url)
                    page.wait_for_function('Boolean(window.checkPreview && window.checkEditorOwner)', timeout=10000)
                    outcomes = []
                    for check in checks:
                        outcome = page.evaluate('''async name => {
                          try {
                            const summary = await Promise.race([window[name](), new Promise((_, reject) =>
                              setTimeout(() => reject(Error("regression timed out")), 10000))]);
                            return {name, ok: true, summary};
                          } catch (error) { return {name, ok: false, error: String(error)}; }
                        }''', check)
                        outcomes.append(outcome)
                result = {'case': name, 'hostSha256': digest(selected_host),
                          'helperSha256': digest(selected_helper), 'checks': outcomes, 'consoleErrors': errors,
                          'bundleSha256': digest(directory / 'app.js'),
                          'bundle': json.loads((directory / 'bundle.json').read_text())}
                results.append(result)
                if expected_failure:
                    assert not outcomes[-1]['ok'] and expected_failure in outcomes[-1]['error'], result
                else:
                    assert all(item['ok'] for item in outcomes) and not errors, result
            finally:
                page.close()
        evidence = {'castRevision': report['castRevision'], 'transport': 'controlled-infoview-peer',
                    'regressionSha256': {name: value for name, value in report['sourceFiles'].items()
                                         if name.startswith('tests/')},
                    'browserVersion': browser.version, 'editorQualified': False,
                    'runtimeOpened': False, 'cases': results}
        (output / 'preview-client.json').write_text(json.dumps(evidence, indent=2) + '\n')
        report['nativeClient'] = {'status': 'controlled-browser-passed',
                                  'negativeControls': ['old-host', 'old-helper'],
                                  'actualEditorObserved': False}
        report_path.write_text(json.dumps(report, indent=2) + '\n')
    finally:
        browser.close()
print('PASS current native host/helper regressions; old progress host and decoder helper both rejected')
