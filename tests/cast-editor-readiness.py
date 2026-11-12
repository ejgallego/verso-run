"""Opt-in real VS Code readiness check in a separately owned diagnostic window.

Prepare the clean editor fixture, launch VS Code with --remote-debugging-port,
then pass that dedicated instance's --cdp URL. The fixture must have no unsaved
edits. This test edits only its buffer and restores it without saving.
"""
import argparse
import json
import re
import time
from pathlib import Path
from playwright.sync_api import Error, sync_playwright

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--cdp', required=True, help='dedicated diagnostic VS Code CDP URL')
parser.add_argument('--output', type=Path, default=ROOT / '_out/cast-editor-readiness')
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
source = ROOT / 'tests/cast/CastEditorFixture.lean'
original = source.read_text()
declaration = next((index + 1, line.index('greet') + 1)
                   for index, line in enumerate(original.splitlines())
                   if line.startswith('public def greet '))
checks = []
result = {'actualEditorObserved': True, 'controlledTransport': False, 'checks': checks}

with sync_playwright() as playwright:
    browser = playwright.chromium.connect_over_cdp(args.cdp)
    editor_selector = '.monaco-editor[data-uri=' + json.dumps(source.as_uri()) + ']'
    matches = []
    deadline = time.monotonic() + 60
    while not matches and time.monotonic() < deadline:
        for context in browser.contexts:
            for candidate in context.pages:
                if candidate.url.startswith('vscode-file:') and candidate.locator(editor_selector).count() == 1:
                    matches.append(candidate)
        if not matches:
            time.sleep(.1)
    assert len(matches) == 1, 'Expected one diagnostic window with this exact fixture URI'
    page = matches[0]
    editor = page.locator(editor_selector)
    group = editor.locator('xpath=ancestor::div[contains(@class,"editor-group-container")][1]')
    assert group.locator('.tab.active[data-resource-name="CastEditorFixture.lean"]').count() == 1
    assert not page.locator('.tab.dirty').count(), 'Preserving unsaved editor edits; use a clean diagnostic window'
    result['fixtureUri'] = source.as_uri()
    frame = None
    deadline = time.monotonic() + 60
    while frame is None and time.monotonic() < deadline:
        frames = []
        for candidate in page.frames:
            try:
                if candidate.locator('[data-cast-preview-current]').count() == 1:
                    frames.append(candidate)
            except Error:
                if not candidate.is_detached():
                    raise
        assert len(frames) <= 1, 'Expected one Manual preview in the diagnostic window'
        if frames:
            frame = frames[0]
        else:
            page.wait_for_timeout(100)
    if frame is None:
        page.screenshot(path=str(args.output / 'infoview-unavailable.png'))
        raise AssertionError('Open the Lean infoview in the diagnostic window; see infoview-unavailable.png')
    slots = frame.locator('[data-lean-run-context=infoview]')
    frame.wait_for_function('''() => {
      const es = [...document.querySelectorAll('[data-lean-run-context=infoview]')];
      return es.length === 4 && es.every(e => !e.querySelector('[type=submit]').disabled);
    }''', timeout=60000)

    def go_to(line, column=1):
        editor.click(position={'x': 150, 'y': 150})
        page.keyboard.press('Control+g')
        box = page.locator('.quick-input-widget .quick-input-box input')
        box.wait_for(state='visible')
        box.fill(f':{line}:{column}')
        page.keyboard.press('Enter')
        box.wait_for(state='hidden')

    def rename_definition(before, after):
        go_to(*declaration)
        for _ in before:
            page.keyboard.press('Shift+ArrowRight')
        page.keyboard.type(after)
        page.keyboard.press('Escape')
        go_to(14)

    def run(index, expected):
        slots.nth(index).locator('[type=submit]').click()
        slots.nth(index).locator('.lean-run-output').filter(has_text=expected).wait_for(timeout=45000)

    try:
        run(0, 'Hello, Ada!')
        checks.append('initial real worker call')
        rename_definition('greet', 'missingGreet')
        frame.wait_for_function('''() => {
          const es = [...document.querySelectorAll('[data-lean-run-context=infoview]')];
          return es.length > 0 && es.every(e => e.querySelector('[type=submit]').disabled);
        }''', timeout=60000)
        # Wait for the error-bearing snapshot, rather than merely stale controls.
        messages = frame.locator('summary').filter(has_text='All Messages').last
        if messages.locator('..').get_attribute('open') is None:
            messages.click()
        diagnostic = messages.locator('..').get_by_text(re.compile(r'Unknown constant\s+`?greet`?'))
        diagnostic.first.wait_for(timeout=60000)
        result['diagnostic'] = diagnostic.first.inner_text()
        frame.wait_for_function("document.querySelector('[data-cast-preview-current=\"true\"]')", timeout=60000)
        result['blockedStatuses'] = slots.locator('.lean-run-status').all_text_contents()
        page.screenshot(path=str(args.output / 'blocked.png'))
        assert result['blockedStatuses'] and all(
            status == 'Fix Lean errors in this page before running.'
            for status in result['blockedStatuses']), result['blockedStatuses']
        checks.append('actual missing-entry diagnostic blocks every visible placement with an explanation')
    finally:
        # The clean-buffer precondition makes all unsaved changes here test-owned.
        go_to(14)
        page.keyboard.press('Control+Shift+p')
        box = page.locator('.quick-input-widget .quick-input-box input')
        box.wait_for(state='visible')
        box.fill('>File: Revert File')
        page.keyboard.press('Enter')
        box.wait_for(state='hidden')
        go_to(14)
        frame.wait_for_function('''() => {
          const es = [...document.querySelectorAll('[data-lean-run-context=infoview]')];
          return es.length === 4 && es.every(e => !e.querySelector('[type=submit]').disabled);
        }''', timeout=60000)
        result['bufferRestored'] = not page.locator('.tab.active.dirty').count()
        result['sourceUnchanged'] = source.read_text() == original
        (args.output / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
    run(0, 'Hello, Ada!')
    run(1, '42')
    checks.append('restoring the definition re-enables inline and anchored real worker calls')
    assert result['bufferRestored'] and result['sourceUnchanged'], result
    page.screenshot(path=str(args.output / 'recovered.png'))
    (args.output / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    browser.close()
