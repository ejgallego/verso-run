"""Exercise official infoview module imports with exact Lean-emitted source.

Requires the compatibility driver's --shell step. Source RPC replies are
controlled; no VIR runtime, real editor connection or worker/CSP gate is claimed.
"""
import argparse
import json
from pathlib import Path
import shutil
import sys

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'tests'))
from harness import serve_directory

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, default=ROOT / '_out/cast-compatibility')
args = parser.parse_args()
output = args.output.resolve()
assert output.is_relative_to(ROOT / '_out')
project = output / 'consumer'
report_path = output / 'results.json'
report = json.loads(report_path.read_text())
assert report['shell']['status'] == 'registered-wrapper-compiled'
shutil.copyfile(ROOT / 'experiments/cast-compatibility/widget-import.html', project / 'widget-import.html')
errors = []
with serve_directory(project) as url, sync_playwright() as playwright:
    browser = playwright.chromium.launch(headless=True, executable_path=shutil.which('google-chrome'))
    try:
        page = browser.new_page()
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.on('console', lambda message: errors.append(message.text) if message.type == 'error' else None)
        page.goto(url + 'widget-import.html')
        page.wait_for_function('window.probeResult?.done', timeout=30000)
        result = page.evaluate('window.probeResult')
        result.update(consoleErrors=errors, browserVersion=browser.version,
                      transport='controlled-widget-source-replies', runtimeOpened=False, editorQualified=False)
        (output / 'widget-import.json').write_text(json.dumps(result, indent=2) + '\n')
        assert result['ok'], result
        assert not errors, errors
        report['shell'].update(loaderQualified='controlled-browser', importChecks=result['checks'])
        report_path.write_text(json.dumps(report, indent=2) + '\n')
    finally:
        browser.close()
print('PASS public widget-module imports, native shell/prop identity and shared React state; editor/runtime unqualified')
