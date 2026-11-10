"""Actual compiled Run adapter and Cast math leaf under controlled editor transport."""
import json
from pathlib import Path
import shutil
from playwright.sync_api import sync_playwright
from harness import serve_directory, run_command

ROOT = Path(__file__).resolve().parent.parent
output = ROOT / '_out/cast-math'
output.mkdir(parents=True, exist_ok=True)
for command, log in [
    (['lake', 'build', '+CastMathDoc:olean'], 'build'),
    (['lake', 'env', 'lean', 'tests/CastMath.lean'], 'prepare'),
    (['node', 'scripts/check-cast-placement.mjs', '--math'], 'bundle'),
]:
    run_command(command, log, output=output, cwd=ROOT)
shutil.copyfile(ROOT / '.vir/infoview.wasm', output / 'runtime.wasm')
errors = []
with serve_directory(output) as url, sync_playwright() as playwright:
    browser = playwright.chromium.launch(headless=True, executable_path=shutil.which('google-chrome'))
    try:
        page = browser.new_page()
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.on('console', lambda message: errors.append(message.text) if message.type == 'error' else None)
        page.goto(url)
        page.wait_for_function('Boolean(window.checkMath)')
        result = page.evaluate('async () => { try { return {ok: true, summary: await window.checkMath()}; } catch(error) { return {ok: false, error: String(error.stack ?? error)}; } }')
        result.update(consoleErrors=errors, browserVersion=browser.version,
                      actualEditorObserved=False, actualWasmAdapter=True)
        page.screenshot(path=str(output / 'math.png'), full_page=True)
        if result['ok']:
            page.evaluate('window.disposeMath()')
        (output / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
        assert result['ok'] and not errors, result
        print(result['summary'])
    finally:
        browser.close()
