"""Native editor placement/worker ownership under controlled transport and worker peers."""
import json
from pathlib import Path
import shutil
import subprocess
from playwright.sync_api import sync_playwright
from harness import serve_directory

ROOT = Path(__file__).resolve().parent.parent
output = ROOT / '_out/cast-placement'
subprocess.run(['node', 'scripts/check-cast-placement.mjs'], cwd=ROOT, check=True)
errors = []
with serve_directory(output) as url, sync_playwright() as playwright:
    browser = playwright.chromium.launch(headless=True, executable_path=shutil.which('google-chrome'))
    try:
        page = browser.new_page()
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.on('console', lambda message: errors.append(message.text) if message.type == 'error' else None)
        page.goto(url)
        page.wait_for_function('Boolean(window.checkPlacement)', timeout=10000)
        result = page.evaluate('async () => { try { return {ok: true, summary: await window.checkPlacement()}; } catch(error) { return {ok: false, error: String(error.stack ?? error)}; } }')
        result.update(consoleErrors=errors, browserVersion=browser.version,
                      transport='controlled-infoview-and-worker-peers', actualEditorObserved=False, runtimeOpened=False)
        (output / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
        assert result['ok'] and not errors, result
        print(result['summary'])
    finally:
        browser.close()
