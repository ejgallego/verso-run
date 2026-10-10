"""Known Life rules and real worker/native generation views in all genres."""
import argparse, functools, json, shutil, subprocess
from pathlib import Path
from playwright.sync_api import sync_playwright
from harness import run_command, serve_directory

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--output', default='_out/life-acceptance')
parser.add_argument('--site', help='reuse the sequence campaign native output')
args = parser.parse_args()
output = Path(args.output).resolve(); output.mkdir(parents=True, exist_ok=True)
checks = []

def record(name):
    checks.append({'test': name, 'result': 'pass'})
    print('PASS', name, flush=True)

command = functools.partial(run_command, output=output, cwd=ROOT)

def oracle(seed):
    return json.loads(json.loads(subprocess.check_output(
        [str(ROOT/'.lake/build/bin/lean-run-oracle'), 'life', seed], text=True)))

command(['lake','env','lean','tests/Life.lean'], 'rules')
record('Lean rules: block, blinker, extinction, translated glider, dead boundaries, parsing and output budget')
site = Path(args.site).resolve() if args.site else output/'site'
if not args.site:
    command(['lake','exe','lean-run-demo','--output',str(site/'manual'),'--with-tex'],'manual')
    command(['lake','exe','lean-run-blog-demo','--output',str(site/'blog')],'blog')
    command(['lake','exe','lean-run-slides-demo','--output',str(site/'slides')],'slides')
served = output/'served'
for prefix in ['root','nested/prefix']:
    for genre, source in [('manual',site/'manual/html-multi'),('blog',site/'blog'),('slides',site/'slides')]:
        shutil.copytree(source,served/prefix/genre,dirs_exist_ok=True)

with serve_directory(served) as base:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True,executable_path=shutil.which('google-chrome'))
        page = browser.new_page(viewport={'width':1280,'height':1000})
        errors = []; page.on('pageerror',lambda error: errors.append(str(error)))
        page.add_init_script("""globalThis.advanceRequests = 0;
          const send = Worker.prototype.postMessage;
          Worker.prototype.postMessage = function(data, ...rest) {
            if (data.operation === 'advance') ++advanceRequests;
            return send.call(this, data, ...rest);
          };""")
        def form(): return page.locator('.lean-run[data-experiment*="LeanRunSequence.Life.lifeView"]').first
        def visit(prefix,genre,path):
            page.goto(base+prefix+'/'+genre+'/'+path)
            page.wait_for_selector('.lean-run[data-enhanced]', state='attached')
            if genre=='slides':
                page.wait_for_function('Reveal.isReady() && globalThis.versoVirState === "ready"')
                form().evaluate('e => {const sections=[...document.querySelectorAll(".reveal .slides > section")];Reveal.slide(sections.indexOf(e.closest(".reveal .slides > section")),0);}')
                form().wait_for(state='visible')
        def current(frame):
            assert frame['html'] in form().locator('iframe[data-preview="current"]').get_attribute('srcdoc')
            assert form().locator('iframe[data-preview="current"]').get_attribute('sandbox') == ''
            assert form().locator('.lean-run-sequence-error').text_content() == (frame['error'] or '')
            assert form().locator('.lean-run-sequence-position').text_content() == frame['label']
        def step(frame):
            form().locator('.lean-run-step').click()
            page.wait_for_function('e => ["success","failed"].includes(e.dataset.state)',arg=form().element_handle())
            assert form().get_attribute('data-state') == 'success', form().inner_text()
            current(frame)
        def run(seed, count=12):
            form().locator('textarea').fill(seed)
            form().locator('[type=submit]').click()
            page.wait_for_function('e => ["success","failed"].includes(e.dataset.state)',arg=form().element_handle(),timeout=30000)
            assert form().get_attribute('data-state')=='success',form().inner_text()
            expected = oracle(seed)
            current(expected[0])
            if expected[0]['error']:
                assert form().frame_locator('iframe[data-preview="current"]').locator('svg').count() == 0
                assert form().locator('.lean-run-play').is_disabled()
                assert form().locator('.lean-run-step').is_disabled()
            else:
                for frame in expected[1:count+1]: step(frame)
                assert form().frame_locator('iframe[data-preview="current"]').locator('svg').get_attribute('aria-label').startswith('Game of Life generation')
            return expected
        for prefix in ['root','nested/prefix']:
            for genre,path in [('manual','Game-of-Life/'),('blog','page/'),
                               ('blog','notes/2026-10-8-running-lean-in-a-post/'),('slides','')]:
                visit(prefix,genre,path)
                expected=run('.#.\n..#\n###')
                assert len(expected)==141 and all(f['error'] is None for f in expected)
                assert 'Generation 12 · 5 living cells' in expected[12]['html']
                record(prefix+'/'+genre+'/'+path+': editable glider and every Lean generation agree with native execution')
        visit('root','manual','Game-of-Life/')
        for seed in ['.##.\n.##.','...\n###\n...','#', '\n'.join(['########']*8)]:
            expected=run(seed)
            assert len(expected)==141 and all(f['error'] is None for f in expected)
        record('still life, blinker, extinction and dense boards execute and render within the worker budget')
        for seed in ['', '#\n..', '#########', '\n'.join(['.']*9), '<script>']:
            expected=run(seed)
            assert expected[0]['error']
        expected=run('.#.\n..#\n###')
        record('invalid shape/character/size is a Lean error frame; a valid seed recovers')
        form().locator('textarea').fill('#')
        assert form().locator('.lean-run-automaton').is_visible()
        assert 'Restart' in form().locator('.lean-run-input-note').inner_text()
        expected=run('...\n###\n...', count=130)
        record('forward execution passes generations 12 and 128 with exact native agreement')
        assert form().locator('[data-step], input[type=range]').count() == 0
        before = form().locator('.lean-run-automaton *').count()
        step(expected[131])
        assert form().locator('.lean-run-automaton *').count() == before
        form().locator('.lean-run-play').click()
        page.wait_for_function('e => e.querySelector(".lean-run-sequence-position").textContent === "Generation 134"',arg=form().element_handle())
        form().locator('.lean-run-play').click()
        page.wait_for_function('e => e.querySelector(".lean-run-status").textContent === "Paused"',arg=form().element_handle())
        label = form().locator('.lean-run-sequence-position').text_content()
        index = int(label.split()[-1]); current(expected[index])
        page.wait_for_timeout(500)
        assert form().locator('.lean-run-sequence-position').text_content() == label
        step(expected[index+1])
        form().locator('.lean-run-play').click()
        page.wait_for_function('(e) => e.querySelector(".lean-run-sequence-position").textContent !== "Generation '+str(index+1)+'"',arg=form().element_handle())
        form().locator('.lean-run-stop').click()
        assert form().get_attribute('data-state') == 'stopped'
        assert form().locator('.lean-run-automaton').is_hidden()
        page.wait_for_timeout(500)
        assert form().get_attribute('data-state') == 'stopped'
        run('...\n###\n...', count=1)
        record('Play advances continuously, Pause preserves the model, Step advances once and Stop prevents late updates; Run restarts')
        # A second placement uses its own worker/model, while sharing resources.
        page.evaluate("""async url => {
            const original = document.querySelector('.lean-run[data-experiment*="LeanRunSequence.Life.lifeView"]');
            const copy = original.cloneNode(true);
            delete copy.dataset.enhanced;
            copy.id = 'independent-life';
            original.after(copy);
            const {enhance} = await import(url);
            enhance(copy);
        }""", base+'root/manual/lean-run/renderer.js')
        other = page.locator('#independent-life')
        other.locator('textarea').fill('.##.\n.##.')
        other.locator('[type=submit]').click()
        page.wait_for_function('e => e.dataset.state === "success"', arg=other.element_handle())
        run('...\n###\n...', count=2)
        expected_other = oracle('.##.\n.##.')
        assert expected_other[0]['html'] in other.locator('iframe[data-preview="current"]').get_attribute('srcdoc')
        other.locator('.lean-run-step').click()
        page.wait_for_function('e => e.dataset.state === "success"', arg=other.element_handle())
        assert expected_other[1]['html'] in other.locator('iframe[data-preview="current"]').get_attribute('srcdoc')
        assert oracle('...\n###\n...')[2]['html'] in form().locator('iframe[data-preview="current"]').get_attribute('srcdoc')
        other.evaluate('e => {e.dispatchEvent(new Event("lean-run-dispose")); e.remove();}')
        record('simultaneous live placements have independent models and can be disposed independently')
        # Editing is a draft even while playback or a transition is active.
        expected = run('...\n###\n...', count=0)
        form().locator('.lean-run-play').click()
        form().locator('textarea').fill('.##.\n.##.')
        page.wait_for_function('e => e.querySelector(".lean-run-sequence-position").textContent === "Generation 3"',arg=form().element_handle())
        assert form().locator('.lean-run-status').inner_text() == 'Playing'
        assert expected[3]['html'] in form().locator('iframe[data-preview="current"]').get_attribute('srcdoc')
        assert 'Restart' in form().locator('.lean-run-input-note').inner_text()
        form().locator('[type=submit]').click()
        page.wait_for_function('e => e.querySelector(".lean-run-status").textContent === "Playing" && e.querySelector(".lean-run-sequence-position").textContent === "Generation 2"',arg=form().element_handle())
        form().locator('.lean-run-play').click()
        page.wait_for_function('e => e.querySelector(".lean-run-status").textContent === "Paused"',arg=form().element_handle())
        index = int(form().locator('.lean-run-sequence-position').text_content().split()[-1])
        assert oracle('.##.\n.##.')[index]['html'] in form().locator('iframe[data-preview="current"]').get_attribute('srcdoc')
        assert form().locator('.lean-run-input-note').inner_text() == ''
        record('seed edits preserve active playback and Restart applies the draft while resuming playback')
        expected = run('...\n###\n...', count=0)
        def hold_preview():
            page.evaluate("""() => {
                const root = document.querySelector('.lean-run-automaton');
                const next = root.querySelector('[data-preview="next"]');
                globalThis.visibleBeforeSwap = root.querySelector('[data-preview="current"]');
                globalThis.loadsHeld = 0;
                const hold = event => { ++loadsHeld; event.stopImmediatePropagation(); };
                next.addEventListener('load', hold);
                globalThis.releasePreview = () => {
                    next.removeEventListener('load', hold);
                    next.dispatchEvent(new Event('load'));
                };
            }""")
        hold_preview()
        count = page.evaluate('advanceRequests')
        form().locator('.lean-run-play').click()
        page.wait_for_function('loadsHeld > 0')
        current(expected[0])
        assert page.evaluate('visibleBeforeSwap === document.querySelector(".lean-run-automaton [data-preview=current]")')
        page.wait_for_timeout(400)
        assert page.evaluate('advanceRequests') == count + 1
        current(expected[0])
        form().locator('.lean-run-play').click()  # Pause with a presentation in flight.
        page.evaluate('releasePreview()')
        page.wait_for_function('e => e.dataset.state === "success"',arg=form().element_handle())
        current(expected[1])
        assert not page.evaluate('visibleBeforeSwap === document.querySelector(".lean-run-automaton [data-preview=current]")')
        hold_preview()
        form().locator('.lean-run-step').click()
        page.wait_for_function('loadsHeld > 0')
        current(expected[1])
        form().locator('.lean-run-stop').click()
        assert form().get_attribute('data-state') == 'stopped'
        page.evaluate('releasePreview()')
        page.wait_for_timeout(100)
        assert form().get_attribute('data-state') == 'stopped'
        assert form().locator('.lean-run-automaton').is_hidden()
        record('staging retains the visible frame and label, applies paint backpressure, swaps after load, and cannot commit after Stop')


        visit('root', 'slides', '')
        run('...\n###\n...', count=1)
        form().locator('.lean-run-play').click()
        page.evaluate('Reveal.slide(0,0)')
        page.wait_for_function('e => ["idle","stopped"].includes(e.dataset.state)',arg=form().element_handle())
        assert form().locator('.lean-run-automaton').is_hidden()
        visit('root', 'manual', 'Game-of-Life/')
        run('...\n###\n...', count=1)
        form().locator('.lean-run-play').click()
        page.evaluate('dispatchEvent(new PageTransitionEvent("pagehide",{persisted:true}))')
        assert form().get_attribute('data-state') == 'idle'
        assert form().locator('.lean-run-automaton').is_hidden()
        run('...\n###\n...', count=1)
        record('leaving an active slide stops playback; cached-page lifetime discards the session and permits restart')


        for width in [1280,390]:
            page.set_viewport_size({'width':width,'height':1000})
            run('.#.\n..#\n###')
            assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
            assert form().frame_locator('iframe[data-preview="current"]').locator('svg').bounding_box()['width']<=176
            page.screenshot(path=str(output/f'life-{width}.png'),full_page=True)
        record('desktop/mobile seed and controls fit, with the full SVG board visible')
        context=browser.new_context(java_script_enabled=False);plain=context.new_page()
        for genre,path in [('manual','Game-of-Life/'),('blog','page/')]:
            plain.goto(base+'root/'+genre+'/'+path)
            static=plain.locator('.lean-run[data-experiment*="LeanRunSequence.Life.lifeView"]')
            assert 'lifeView' in static.locator('.lean-run-source').text_content()
            assert static.locator('details.lean-run-source').count() == 0
            assert 'Board.neighbours' in plain.locator('body').inner_text()
            assert 'renderState' in plain.locator('body').inner_text()
            assert static.locator('[type=submit]').is_disabled()
        assert 'lifeView' in (site/'manual/tex/main.tex').read_text()
        context.close()
        assert not errors,errors
        record('all genres retain static source, Manual TeX, and no uncaught browser errors')
        browser.close()
(output/'results.json').write_text(json.dumps({'checks':checks},indent=2)+'\n')
print(f'{len(checks)} Life checks passed; evidence: {output}',flush=True)
