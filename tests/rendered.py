"""Typed inputs, native view payloads and the shared compiled DOM presenter."""
import argparse, functools, json, shutil, subprocess
from pathlib import Path
from playwright.sync_api import sync_playwright
from harness import run_command, serve_directory

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--output', default='_out/rendered-acceptance')
output = Path(parser.parse_args().output).resolve()
output.mkdir(parents=True, exist_ok=True)
command = functools.partial(run_command, output=output, cwd=ROOT)
checks = []
def record(name):
    checks.append({'test': name, 'result': 'pass'})
    print('PASS', name, flush=True)
def oracle(role, value):
    return json.loads(subprocess.check_output([str(ROOT/'.lake/build/bin/lean-run-oracle'), role, value], text=True))

site = output/'site'
for executable, genre in [('lean-run-demo','manual'),('lean-run-blog-demo','blog'),('lean-run-slides-demo','slides')]:
    command(['lake','exe',executable,'--output',str(site/genre)], genre)
paths = [('manual',site/'manual/html-multi','Typed-rendering/'),
         ('blog',site/'blog','page/'),
         ('post',site/'blog','notes/2026-10-8-running-lean-in-a-post/'),
         ('slides',site/'slides','')]
with serve_directory(site) as base, sync_playwright() as p:
    browser = p.chromium.launch(headless=True, executable_path=shutil.which('google-chrome'))
    page = browser.new_page()
    errors = []
    page.on('pageerror', lambda error: errors.append(str(error)))
    for genre, root, path in paths:
        plan = json.loads((root/'lean-run/publication.json').read_text())
        assert set(plan['presenters']) == {'html','sequence','automaton'}
        assert plan['presenters']['automaton']['expectedExport']['effect'] == 'dom'
        assert plan['presenters']['automaton']['expectedExport']['result']['type'] == 'Unit'
        assert plan['presenters']['automaton']['expectedExport']['args'][1]['name'] == 'VersoLeanRun.SequenceWire.Frame'
        assert plan['presenters']['html']['expectedExport']['effect'] == 'dom'
        assert plan['presenters']['html']['expectedExport']['result']['type'] == 'Unit'
        assert plan['presenters']['sequence']['expectedExport']['args'][1]['kind'] == 'structure'
        prefix = 'blog' if genre == 'post' else genre
        if genre == 'manual': prefix += '/html-multi'
        page.goto(base+prefix+'/'+path)
        page.wait_for_selector('.lean-run[data-enhanced]')
        def form(entry): return page.locator('.lean-run[data-experiment*="LeanRunRendered.Examples.'+entry+'"]')
        def show(selected, value):
            if genre == 'slides':
                selected.evaluate('e => {const sections=[...document.querySelectorAll(".reveal .slides > section")];Reveal.slide(sections.indexOf(e.closest(".reveal .slides > section")),0);}')
            field = selected.locator('input[type=text], select')
            if field.evaluate('e => e.tagName') == 'SELECT': field.select_option(value)
            else: field.fill(value)
            selected.locator('[type=submit]').click()
            page.wait_for_function('e => ["success","failed"].includes(e.dataset.state)',arg=selected.element_handle(),timeout=30000)
            assert selected.get_attribute('data-state') == 'success', selected.inner_text()
        badge = form('badge')
        assert json.loads(badge.get_attribute('data-experiment'))['form'] == 'boolHtml'
        for value in ['true','false']:
            show(badge,value)
            assert oracle('badge',value) in badge.locator('iframe').get_attribute('srcdoc')
            assert badge.locator('iframe').get_attribute('sandbox') == ''
            assert badge.frame_locator('iframe').locator('strong').inner_text() == ('Enabled' if value=='true' else 'Disabled')
        record(genre+': Bool input and compiled Html presentation agree with native Lean')
        steps = form('wordSteps')
        assert json.loads(steps.get_attribute('data-experiment'))['form'] == 'uint64Sequence'
        for value in ['9007199254740993','18446744073709551615']:
            show(steps,value)
            expected = json.loads(oracle('wordSteps',value))
            for i, frame in enumerate(expected['frames']):
                steps.locator(f'[data-step="{i}"]').click()
                assert frame['html'] in steps.locator('iframe').get_attribute('srcdoc')
        assert 'Exact word: 0' in steps.frame_locator('iframe').locator('p').inner_text()
        record(genre+': UInt64 input survives typed worker transfer with exact values and wraparound')
        steps.locator('input[type=text]').fill('18446744073709551616')
        steps.locator('[type=submit]').click()
        assert steps.get_attribute('data-state') == 'invalid input'
        assert steps.locator('.lean-run-sequence').is_hidden()
        assert steps.locator('[type=submit]').is_enabled()
        record(genre+': invalid typed input clears its old presentation before invoking')
    page.goto(base+'manual/html-multi/Illuminate-diagrams/')
    page.wait_for_selector('.lean-run[data-enhanced]')
    diagram = page.locator('.lean-run[data-experiment*="LeanRunGate.diagram"]')
    assert json.loads(diagram.get_attribute('data-experiment'))['form'] == 'natHtml'
    diagram.locator('input').fill('4'); diagram.locator('[type=submit]').click()
    page.wait_for_function('e => e.dataset.state==="success"',arg=diagram.element_handle(),timeout=30000)
    assert oracle('diagram','4') in diagram.locator('iframe').get_attribute('srcdoc')
    assert diagram.frame_locator('iframe').locator('svg text').all_text_contents() == ['1','2','3','4']
    record('Nat → Html uses the qualified Illuminate drawing/SVG path without String parsing')
    assert not errors, errors
    record('no uncaught typed rendering errors')
    browser.close()
(output/'results.json').write_text(json.dumps({'checks':checks},indent=2)+'\n')
print(f'{len(checks)} rendered checks passed', flush=True)
