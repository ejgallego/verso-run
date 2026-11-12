"""Native editor placement/worker ownership under controlled transport and worker peers."""
import json
from pathlib import Path
import shutil
from playwright.sync_api import sync_playwright
from harness import serve_directory, run_command

ROOT = Path(__file__).resolve().parent.parent
output = ROOT / '_out/cast-placement'
output.mkdir(parents=True, exist_ok=True)
for command, log in [
    (['lake', 'build', '+CastSourceGate:olean'], 'build'),
    (['lake', 'env', 'lean', 'tests/CastPlacement.lean'], 'prepare'),
    (['lake', 'env', 'lean', 'tests/CastSources.lean'], 'contracts'),
    (['node', 'scripts/check-cast-placement.mjs'], 'bundle'),
]:
    run_command(command, log, output=output, cwd=ROOT)
shutil.copyfile(ROOT / '.vir/infoview.wasm', output / 'runtime.wasm')
shutil.copyfile(ROOT / '_out/rc2-demo/source-contracts.json', output / 'contracts.json')
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
                      transport='controlled-infoview-and-worker-peers', actualEditorObserved=False, runtimeOpened=True, actualWasmAdapter=True)
        (output / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
        assert result['ok'] and not errors, result
        print(result['summary'])
    finally:
        browser.close()
