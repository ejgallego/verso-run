"""Native Slides publication and real Reveal/worker behavior at root and nested URLs."""
from harness import run_command, inventory, serve_directory
import argparse, functools, json, shutil, subprocess, time
from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--output', default='_out/slides-acceptance')
output = Path(parser.parse_args().output).resolve()
output.mkdir(parents=True, exist_ok=True)
checks = []
command = functools.partial(run_command, output=output, cwd=ROOT)

def record(name):
    checks.append({'test': name, 'result': 'pass'})
    print('PASS', name, flush=True)


def oracle(role, value):
    return json.loads(subprocess.check_output(
        [str(ROOT/'.lake/build/bin/lean-run-blog-oracle'), role, value], text=True))

site = output/'site'
command(['lake', 'exe', 'lean-run-slides-demo', '--output', str(site)], 'generate')
plan = json.loads((site/'lean-run/publication.json').read_text())
assert set(plan['programs']) == {'LeanRunSlides.Deck'}
assert len(plan['programs']['LeanRunSlides.Deck']) == 10
assert plan['runtimeModule'].startswith('lib/vir/')
assert len(list(site.rglob('runtime.js'))) == 1
assert len(list(site.rglob('bundle.json'))) == 4  # runtime, formatter, document callables, DOM presenter
record('typed deck collection composes one runtime with formatter and document-selected callables')
(output/'lean-toolchain').write_text((ROOT/'lean-toolchain').read_text())
command([str(ROOT/'.lake/build/bin/lean-run-slides-demo'), '--output', str(output/'native-only')],
        'native-only', cwd=output)
assert plan == json.loads((output/'native-only/lean-run/publication.json').read_text())
assert inventory(site/'lib/vir') == inventory(output/'native-only/lib/vir')
assert inventory(site/'lean-run') == inventory(output/'native-only/lean-run')
record('Slides native generator runs outside checkout with embedded code and assets')
accepted = (site/'lean-run/publication.json').read_bytes()
index = (site/'index.html').read_bytes()
for mode, reason in [('missing', 'no published program bundle'),
                     ('malformed', 'Invalid Slides Lean Run metadata'),
                     ('collision', 'Filename collision in config')]:
    for destination in [site, output/('rejected-'+mode)]:
        error = command(['lake', 'exe', 'lean-run-slides-demo', '--check', mode, '--output', str(destination)],
                        mode+'-'+destination.name, expected=1)
        assert reason in error, error
    assert (site/'lean-run/publication.json').read_bytes() == accepted
    assert (site/'index.html').read_bytes() == index
    assert not (output/('rejected-'+mode)/'index.html').exists()
    assert not (output/('rejected-'+mode)/'lean-run/publication.json').exists()
    record(mode+' fails before any fresh or accepted slide publication is overwritten')


served = output/'served'
for prefix in ['root', 'nested/prefix/slides']:
    shutil.copytree(site, served/prefix, dirs_exist_ok=True)
with serve_directory(served) as base:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True, executable_path=shutil.which('google-chrome'))
        page = browser.new_page(viewport={'width': 1280, 'height': 900})
        errors = []
        page.on('pageerror', lambda error: errors.append(str(error)))

        def form(name):
            return page.locator('.lean-run[data-experiment*="'+name+'"]').first

        def slide(index):
            page.evaluate('(n) => Reveal.slide(n, 0)', index)
            if page.evaluate('Reveal.isScrollView()'):
                for _ in range(6):
                    page.wait_for_timeout(100)
                    current = page.evaluate('Reveal.getIndices().h')
                    if current == index: break
                    page.evaluate('Reveal.next()' if current < index else 'Reveal.prev()')
            page.wait_for_function('(n) => Reveal.getIndices().h === n', arg=index)

        def no_workers():
            deadline = time.monotonic() + 5
            while page.workers and time.monotonic() < deadline:
                page.wait_for_timeout(50)
            assert not page.workers

        def call(selected, value, keyboard=False):
            selected.locator('input').fill(value)
            if keyboard: selected.locator('input').press('Enter')
            else: selected.locator('[type=submit]').click()
            page.wait_for_function('e => ["success", "failed"].includes(e.dataset.state)',
                                   arg=selected.element_handle(), timeout=30000)
            assert selected.get_attribute('data-state') == 'success', selected.inner_text()
            return selected.locator('.lean-run-output').text_content()

        for prefix in ['root', 'nested/prefix/slides']:
            page.goto(base+prefix+'/')
            page.wait_for_selector('.lean-run[data-enhanced]')
            page.wait_for_function('Reveal.isReady() && globalThis.versoVirState === "ready"')
            assert len(page.workers) == 0
            selected = form('LeanRunGate.Helper.twice')
            assert selected.locator('.lean-run-source .hl.lean').count() > 0
            assert selected.locator('[data-verso-hover]').count() > 0
            for value in ['0', '9007199254740993', '9'*128]:
                assert call(selected, value) == oracle('twice', value)
            selected.locator('input').press('ArrowRight')
            assert page.evaluate('Reveal.getIndices().h') == 0
            assert call(selected, '21', keyboard=True) == oracle('twice', '21')
            assert page.evaluate('Reveal.getIndices().h') == 0
            record(prefix+': native highlighting, lazy Run worker, exact Nat, and keyboard submission')
            slide(1)
            assert selected.get_attribute('data-state') == 'stopped'
            greeting = form('LeanRunBlog.Examples.greet')
            assert greeting.locator('[type=submit]').is_disabled()
            # A hidden form cannot start a worker even through synthetic submission.
            greeting.locator('form').evaluate('(e) => e.dispatchEvent(new Event("submit", {bubbles:true,cancelable:true}))')
            assert greeting.get_attribute('data-state') == 'stopped'
            page.evaluate('Reveal.nextFragment()')
            assert call(greeting, '世界 🌍 <b>&') == oracle('greet', '世界 🌍 <b>&')
            assert greeting.locator('.lean-run-output b').count() == 0
            page.evaluate('Reveal.prevFragment()')
            assert greeting.get_attribute('data-state') == 'stopped'
            assert greeting.locator('.lean-run-output').text_content() == ''
            assert greeting.locator('[type=submit]').is_disabled()
            page.evaluate('Reveal.nextFragment()')
            assert call(greeting, 'fresh fragment') == oracle('greet', 'fresh fragment')
            record(prefix+': native fragment show/hide stops its worker and supports fresh invocation')
            slide(2)
            count = form('LeanRunBlog.Examples.count')
            assert count.locator('details.lean-run-source').count() == 1
            assert call(count, '10') == oracle('count', '10')
            for stop_by_slide in [False, True]:
                count.locator('input').fill('1000000000000')
                count.locator('[type=submit]').click()
                page.wait_for_function('e => e.dataset.state === "running"', arg=count.element_handle(), timeout=30000)
                if stop_by_slide: slide(3)
                else: count.locator('.lean-run-stop').click()
                assert count.get_attribute('data-state') == 'stopped'
                slide(2)
                assert call(count, '11') == oracle('count', '11')
            record(prefix+': real synchronous Stop and slide navigation terminate work before fresh rerun')
            slide(3)
            card = form('LeanRunBlog.Examples.card')
            assert call(card, '<b>& Ada') == ''
            frame = card.locator('iframe')
            assert oracle('card', '<b>& Ada') in frame.get_attribute('srcdoc')
            assert frame.get_attribute('sandbox') == ''
            assert card.frame_locator('iframe').locator('b').count() == 0
            slide(0)
            assert frame.get_attribute('srcdoc') is None
            assert frame.is_hidden()
            no_workers()
            record(prefix+': escaped isolated HTML preview and all workers are cleared on navigation')

        # Failure and cancellation during acquisition use the shared host guards.
        page.reload()
        page.wait_for_selector('.lean-run[data-enhanced]')
        page.wait_for_function('Reveal.isReady()')
        slide(2)
        count = form('LeanRunBlog.Examples.count')
        program = plan['programs']['LeanRunSlides.Deck']['LeanRunBlog.Examples.count']['manifest'].replace('bundle.json', 'program.irpkg')
        page.route('**/'+program, lambda route: route.fulfill(status=404, body='missing'))
        count.locator('[type=submit]').click()
        page.wait_for_function('e => e.dataset.state === "failed"', arg=count.element_handle(), timeout=30000)
        assert '404' in count.locator('.lean-run-output').text_content()
        page.unroute('**/'+program)
        assert call(count, '12') == oracle('count', '12')
        record('Slides program failure reports text and explicit retry recovers')
        count.locator('input').fill('1000000000000')
        held = []
        page.route('**/'+program, lambda route: held.append(route))
        count.locator('[type=submit]').click()
        deadline = time.monotonic() + 5
        while not held and time.monotonic() < deadline:
            page.wait_for_timeout(50)
        assert held, 'the worker acquisition request must be held before navigation'
        assert count.get_attribute('data-state') == 'loading'
        slide(0)
        assert count.get_attribute('data-state') == 'stopped'
        for route in held:
            route.fulfill(status=404, body='late failure')
        page.unroute('**/'+program)
        page.wait_for_timeout(100)
        assert count.get_attribute('data-state') == 'stopped'
        assert count.locator('.lean-run-output').text_content() == ''
        slide(2)
        assert call(count, '13') == oracle('count', '13')
        record('navigation during invocation cannot publish a stale result; return permits a fresh call')
        slide(0)
        assert call(form('LeanRunGate.Helper.twice'), '21') == oracle('twice', '21')
        for width in [1280, 390]:
            page.set_viewport_size({'width': width, 'height': 900})
            page.wait_for_function('document.documentElement.scrollWidth <= innerWidth')
            if width == 390:
                selected = form('LeanRunGate.Helper.twice')
                assert selected.locator('[type=submit]').bounding_box()['height'] >= 44
            result = form('LeanRunGate.Helper.twice').locator('.lean-run-output')
            assert result.bounding_box()['width'] > 0.8 * form('LeanRunGate.Helper.twice').bounding_box()['width']
            page.screenshot(path=str(output/f'slides-{width}.png'))
        record('Reveal and Run controls fit desktop and narrow viewports')
        page.wait_for_function('Reveal.isScrollView()')
        page.evaluate('document.fonts.ready')
        slide(2)
        count = form('LeanRunBlog.Examples.count')
        count.locator('input').fill('1000000000000')
        count.locator('[type=submit]').click()
        page.wait_for_function('e => e.dataset.state === "running"', arg=count.element_handle(), timeout=30000)
        page.mouse.move(200, 700)
        page.mouse.wheel(0, 1500)
        page.wait_for_function('Reveal.getIndices().h !== 2')
        assert count.get_attribute('data-state') == 'stopped'
        no_workers()
        record('mobile scroll navigation stops an actual running worker')
        slide(2)
        count.locator('input').fill('1000000000000')
        count.locator('[type=submit]').click()
        page.wait_for_function('e => e.dataset.state === "running"', arg=count.element_handle(), timeout=30000)
        before = count.get_attribute('data-instance')
        page.set_viewport_size({'width': 1280, 'height': 900})
        page.wait_for_function('!Reveal.isScrollView()')
        page.wait_for_function('(id) => [...document.querySelectorAll(".lean-run")].every(e => e.dataset.enhanced) && !document.querySelector(`[data-instance="${id}"]`)', arg=before)
        no_workers()
        slide(2)
        assert call(form('LeanRunBlog.Examples.count'), '14') == oracle('count', '14')
        record('leaving scroll view disposes detached workers and rebinds restored controls')
        plain = browser.new_context(java_script_enabled=False)
        tab = plain.new_page()
        tab.goto(base+'root/')
        tab.set_viewport_size({'width': 390, 'height': 900})
        assert tab.evaluate('document.documentElement.scrollWidth <= innerWidth')
        for name in ['LeanRunGate.Helper.twice', 'LeanRunBlog.Examples.count']:
            selected = tab.locator('.lean-run[data-experiment*="'+name+'"]').first
            assert 'public def' in selected.locator('.lean-run-source').text_content()
            assert selected.locator('.lean-run-source').is_visible()
            assert selected.locator('[type=submit]').is_disabled()
        plain.close()
        record('Slides retain native source and disabled controls without JavaScript')
        assert not errors, errors
        record('no uncaught Slides browser errors')
        browser.close()
(output/'results.json').write_text(json.dumps({'checks': checks, 'publication': plan}, indent=2)+'\n')
print(f'{len(checks)} Slides checks passed; evidence: {output}', flush=True)
