"""Hold the real presenter module request across deadline/Stop and late evaluation."""
from harness import serve_directory
import argparse, json, shutil, time
from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--site', required=True)
parser.add_argument('--output', default='_out/sequence-import')
args = parser.parse_args()
site = Path(args.site).resolve()
output = Path(args.output).resolve()
output.mkdir(parents=True, exist_ok=True)
plan = json.loads((site/'lean-run/publication.json').read_text())

checks = []
with serve_directory(site) as base:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True, executable_path=shutil.which('google-chrome'))
        for mode in ['deadline', 'stop']:
            page = browser.new_page()
            errors = []
            page.on('pageerror', lambda error: errors.append(str(error)))
            held = []
            waiting_plan = json.loads(json.dumps(plan))
            waiting_plan['runtimeModule'] += '?sequence-import-' + mode
            publications = [0]
            def publication(route):
                publications[0] += 1
                # Keep the evaluator's module untouched; hold only the subsequent
                # presenter import in the window context.
                selected = plan if publications[0] == 1 else waiting_plan
                route.fulfill(content_type='application/json', body=json.dumps(selected))
            page.route('**/lean-run/publication.json', publication)
            page.route('**/*?sequence-import-' + mode, lambda route: held.append(route))
            page.goto(base + 'Stack-stepper/')
            form = page.locator('.lean-run[data-experiment*="stackView"]')
            page.wait_for_selector('.lean-run[data-enhanced]')
            page.evaluate("""async () => {
                globalThis.importProbe = {settled: [], created: 0, evaluated: 0, unhandled: []};
                addEventListener('unhandledrejection', event => importProbe.unhandled.push(String(event.reason)));
                const source = document.querySelector('.lean-run[data-experiment*=stackView]');
                const renderer = new URL(source.dataset.leanRunRenderer ||
                    '../lean-run/renderer.js', location.href);
                const {SequencePlayer} = await import(new URL('./sequence.js', renderer).href);
                const show = SequencePlayer.prototype.show;
                SequencePlayer.prototype.show = function(data) {
                    const result = show.call(this, data);
                    result.then(value => importProbe.settled.push(value),
                                error => importProbe.settled.push(String(error)));
                    return result;
                };
            }""")
            started = time.monotonic()
            form.locator('[type=submit]').click()
            deadline = time.monotonic() + 10
            while not held and time.monotonic() < deadline: page.wait_for_timeout(25)
            assert len(held) == 1
            assert form.get_attribute('data-state') == 'loading view'
            if mode == 'stop':
                form.locator('.lean-run-stop').click()
                page.wait_for_function('importProbe.settled.length === 1', timeout=2000)
                assert form.get_attribute('data-state') == 'stopped'
            else:
                page.wait_for_function('importProbe.settled.length === 1', timeout=20000)
                assert form.get_attribute('data-state') == 'failed'
                assert 'timed out' in form.locator('.lean-run-output').text_content()
            assert page.evaluate('importProbe.settled') == [False]
            assert page.evaluate('importProbe.evaluated') == 0
            assert form.locator('.lean-run-sequence').is_hidden()
            assert form.locator('[type=submit]').is_enabled()
            settled_seconds = time.monotonic() - started
            # Retry with the real module while the abandoned module is STILL held.
            page.unroute('**/lean-run/publication.json', publication)
            form.locator('input[type=text]').fill('5 dup *')
            form.locator('[type=submit]').click()
            page.wait_for_function('importProbe.settled.length === 2', timeout=30000)
            assert page.evaluate('importProbe.settled') == [False, True]
            assert form.get_attribute('data-state') == 'success'
            assert form.locator('.lean-run-sequence-controls').count() == 1
            # Real module evaluation can still happen after cancellation. Test
            # both a late success and a rejected import without creating a VM.
            tail = 'throw new Error("late runtime import rejection");' if mode == 'stop' else ''
            held[0].fulfill(content_type='text/javascript', body='''
                globalThis.importProbe.evaluated++;
                export function createProgram() {
                    globalThis.importProbe.created++;
                    throw new Error("stale presenter allocation");
                }
            ''' + tail)
            page.wait_for_function('importProbe.evaluated === 1')
            page.wait_for_timeout(100)
            assert page.evaluate('importProbe.created') == 0
            assert page.evaluate('importProbe.unhandled') == []
            assert form.get_attribute('data-state') == 'success'
            assert form.locator('.lean-run-sequence-controls').count() == 1
            assert 'Step 1 of 4' in form.locator('.lean-run-sequence-position').text_content()
            form.locator('.lean-run-sequence-next').click()
            assert 'Step 2 of 4' in form.locator('.lean-run-sequence-position').text_content()
            assert not errors, errors
            checks.append({'mode': mode, 'settledSeconds': settled_seconds,
                           'retryBeforeModuleRelease': True, 'lateEvaluation': True,
                           'staleProgramsCreated': 0, 'unhandledRejections': []})
            print('PASS held module: ' + mode + ', prompt settlement, retry and observed late outcome', flush=True)
            page.close()
        browser.close()
(output/'results.json').write_text(json.dumps({'checks': checks, 'publication': plan}, indent=2)+'\n')
