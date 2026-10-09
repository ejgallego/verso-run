"""Typed Lean sequences and the Lean/VIR DOM player, with real worker/native agreement."""
import argparse, functools, http.server, json, shutil, subprocess, threading, time
from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--output', default='_out/sequence-acceptance')
output = Path(parser.parse_args().output).resolve()
output.mkdir(parents=True, exist_ok=True)
checks = []

def record(name):
    checks.append({'test': name, 'result': 'pass'})
    print('PASS', name, flush=True)

def command(args, name):
    run = subprocess.run(args, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (output/(name+'.log')).write_text(run.stdout)
    assert run.returncode == 0, run.stdout[-4000:]

def oracle(value):
    return json.loads(json.loads(subprocess.check_output(
        [str(ROOT/'.lake/build/bin/lean-run-oracle'), 'sequence', value], text=True)))

command(['lake','env','lean','tests/SequenceAdapter.lean'],'generic-author')
record('generic String-state author API selects and reuses the automatic adapter; empty/versioned payloads are rejected')
site = output/'site'
command(['lake','exe','lean-run-demo','--output',str(site/'manual'),'--with-tex'], 'manual')
command(['lake','exe','lean-run-blog-demo','--output',str(site/'blog')], 'blog')
command(['lake','exe','lean-run-slides-demo','--output',str(site/'slides')], 'slides')
plans = {}
for genre, path in [('manual',site/'manual/html-multi'),('blog',site/'blog'),('slides',site/'slides')]:
    plan = plans[genre] = json.loads((path/'lean-run/publication.json').read_text())
    presenter = plan['presenters']['sequence']
    assert presenter['expectedExport']['effect'] == 'dom'
    assert presenter['expectedExport']['args'][0]['name'] == 'Lean.Vir.Browser.Element'
    assert presenter['expectedExport']['args'][1] == {'type':'String','interfaceTag':3}
    for owner, bindings in plan['programs'].items():
        if 'LeanRunSequence.Examples.stackView' in bindings:
            assert bindings['LeanRunSequence.Examples.stackView']['expectedExport'] == {
                'args':[{'type':'String','interfaceTag':3}],
                'result':{'type':'String','interfaceTag':3},'effect':'pure'}
record('all genres independently classify pure sequence adapters and the separate DOM presenter')

class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self,*_): pass
    def handle(self):
        try: super().handle()
        except (BrokenPipeError,ConnectionResetError): pass

served = output/'served'
for prefix in ['root','nested/prefix']:
    for genre,path in [('manual',site/'manual/html-multi'),('blog',site/'blog'),('slides',site/'slides')]:
        shutil.copytree(path,served/prefix/genre,dirs_exist_ok=True)
server = http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(QuietHandler,directory=str(served)))
threading.Thread(target=server.serve_forever,daemon=True).start()
base = f'http://127.0.0.1:{server.server_port}/'
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True,executable_path=shutil.which('google-chrome'))
        page = browser.new_page(viewport={'width':1280,'height':1000})
        errors = []
        page.on('pageerror',lambda error:errors.append(str(error)))
        def form(): return page.locator('.lean-run[data-experiment*="LeanRunSequence.Examples.stackView"]')
        def visit(prefix,genre,path):
            page.goto(base+prefix+'/'+genre+'/'+path)
            page.wait_for_selector('.lean-run[data-enhanced]')
            if genre == 'slides':
                page.wait_for_function('Reveal.isReady() && globalThis.versoVirState === "ready"')
                page.evaluate('Reveal.slide(10,0)')
                page.wait_for_function('Reveal.getIndices().h === 10')
        def run(value, selected=None):
            f=form() if selected is None else selected;f.locator('input[type=text]').fill(value);f.locator('[type=submit]').click()
            page.wait_for_function('e => ["success","failed"].includes(e.dataset.state)',arg=f.element_handle(),timeout=30000)
            assert f.get_attribute('data-state') == 'success', f.inner_text()
            assert f.locator('.lean-run-sequence-frame').is_visible()
            return oracle(value)
        def select(index, expected):
            f=form();f.locator(f'[data-step="{index}"]').click()
            frame=expected['frames'][index]
            assert f.locator('.lean-run-sequence-position').text_content() == f"Step {index+1} of {len(expected['frames'])}: {frame['label']}"
            assert frame['html'] in f.locator('iframe').get_attribute('srcdoc')
            assert f.locator('.lean-run-sequence-error').text_content() == (frame['error'] or '')
            assert f.locator('iframe').get_attribute('sandbox') == ''

        for prefix in ['root','nested/prefix']:
            for genre,path in [('manual','Stack-stepper/'),('blog','page/'),
                               ('blog','notes/2026-10-8-running-lean-in-a-post/'),('slides','')]:
                visit(prefix,genre,path)
                expected=run('6 7 * 2 +')
                count=len(page.workers)
                for index in range(len(expected['frames'])): select(index,expected)
                assert len(page.workers)==count, 'Selecting a state must not rerun the evaluator'
                form().locator('.lean-run-sequence-prev').click()
                assert 'Step 5 of 6' in form().locator('.lean-run-sequence-position').text_content()
                slider=form().locator('input[type=range]')
                slider.evaluate('(e) => {e.value="0";e.dispatchEvent(new Event("input",{bubbles:true}));}')
                assert 'Step 1 of 6' in form().locator('.lean-run-sequence-position').text_content()
                if genre=='slides': assert page.evaluate('Reveal.getIndices().h')==10
                record(prefix+'/'+genre+'/'+path+': Lean controls select every native frame, navigate and scrub without another worker call')
                for value in ['9007199254740993 2 *','2 +','2 unknown','', ' '.join(['1']*33)]:
                    expected=run(value)
                    for index in range(len(expected['frames'])): select(index,expected)
                record(prefix+'/'+genre+'/'+path+': exact Nat stacks, underflow/parse errors and input bounds agree with native Lean')

        visit('root','blog','page/')
        page.evaluate("""async () => {
            const source=document.querySelector('.lean-run[data-experiment*="stackView"]');
            const copy=source.cloneNode(true);
            delete copy.dataset.enhanced;
            source.after(copy);
            const {enhance}=await import(new URL(source.dataset.leanRunRenderer,location.href).href);
            enhance(copy);
        }""")
        first,second=form().nth(0),form().nth(1)
        run('6 7 * 2 +',first);run('5 dup *',second)
        first.locator('.lean-run-sequence-next').click()
        assert 'Step 2 of 6' in first.locator('.lean-run-sequence-position').text_content()
        assert 'Step 1 of 4' in second.locator('.lean-run-sequence-position').text_content()
        first.locator('input[type=text]').fill('changed')
        second.locator('.lean-run-sequence-next').click()
        assert 'Step 2 of 4' in second.locator('.lean-run-sequence-position').text_content()
        assert first.locator('.lean-run-sequence').is_hidden()
        record('two placements retain independent Lean selection and runtime state; clearing one preserves the other')

        visit('root','manual','Stack-stepper/')
        expected=run('2 +');select(2,expected)
        page.evaluate('globalThis.oldStep = document.querySelector(".lean-run-sequence-next")')
        form().locator('input[type=text]').fill('5 dup *')
        assert form().locator('.lean-run-sequence').is_hidden()
        page.evaluate('oldStep.click()')
        assert form().get_attribute('data-state')=='idle'
        expected=run('5 dup *');select(3,expected)
        record('input edits remove native listeners and stale controls; new input gets a fresh presentation')

        # Stop while only the main-thread presenter is loading; the evaluator has finished.
        visit('root','manual','Stack-stepper/')
        held=[]
        ui_prefix=plans['manual']['presenters']['sequence']['manifest'].rsplit('/',1)[0]
        page.route('**/'+ui_prefix+'/program.irpkg',lambda route:held.append(route))
        form().locator('[type=submit]').click()
        page.wait_for_function('e => e.dataset.state === "loading view"',arg=form().element_handle())
        deadline=time.monotonic()+15
        while not held and time.monotonic()<deadline: page.wait_for_timeout(25)
        assert held
        form().locator('.lean-run-stop').click()
        assert form().get_attribute('data-state')=='stopped'
        for route in held: route.abort()
        page.unroute('**/'+ui_prefix+'/program.irpkg')
        page.wait_for_timeout(100)
        assert form().locator('.lean-run-sequence').is_hidden()
        run('6 7 * 2 +')
        record('Stop cancels pending presenter acquisition, suppresses stale mounting and permits explicit retry')

        visit('root','manual','Stack-stepper/')
        bad=json.loads(json.dumps(plans['manual']))
        bad['presenters']['sequence']['expectedExport']['result']={'type':'String','interfaceTag':3}
        page.route('**/lean-run/publication.json',lambda route:route.fulfill(content_type='application/json',body=json.dumps(bad)))
        form().locator('[type=submit]').click()
        page.wait_for_function('e => e.dataset.state === "failed"',arg=form().element_handle(),timeout=30000)
        message=form().locator('.lean-run-output').text_content().lower()
        assert 'signature' in message or 'mismatch' in message, message
        assert form().locator('.lean-run-sequence').is_hidden()
        page.unroute('**/lean-run/publication.json')
        run('1 2 +')
        record('independent presenter signature mismatch rejects before mounting; explicit retry recovers')

        visit('root','slides','');run('6 7 * 2 +')
        page.evaluate('globalThis.oldStep=document.querySelector(".lean-run-sequence-next");Reveal.slide(9,0)')
        page.wait_for_function('Reveal.getIndices().h === 9')
        page.evaluate('oldStep.click()')
        assert form().locator('.lean-run-sequence').is_hidden()
        page.evaluate('Reveal.slide(10,0)')
        run('5 dup *')
        record('Slides navigation removes DOM listeners and disposes its presentation; returning permits a fresh run')

        for width in [1280,390]:
            page.set_viewport_size({'width':width,'height':1000})
            visit('root','manual','Stack-stepper/');expected=run('9007199254740993 2 *');select(3,expected)
            assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
            page.screenshot(path=str(output/f'sequence-{width}.png'),full_page=True)
        record('desktop and mobile sequence controls fit; exact state values remain readable')

        context=browser.new_context(java_script_enabled=False)
        plain=context.new_page()
        for genre,path in [('manual','Stack-stepper/'),('blog','page/'),('slides','')]:
            plain.goto(base+'root/'+genre+'/'+path)
            f=plain.locator('.lean-run[data-experiment*="stackView"]')
            assert 'SequenceView' in f.locator('.lean-run-source').text_content()
            assert f.locator('[type=submit]').is_disabled()
        context.close()
        assert 'stackView' in (site/'manual/tex/main.tex').read_text()
        record('all genres retain static source; Manual TeX retains the typed sequence entry')
        assert not errors, errors
        record('no uncaught sequence browser errors')
        browser.close()
finally:
    server.shutdown();server.server_close()
(output/'results.json').write_text(json.dumps({'checks':checks,'publication':plans},indent=2)+'\n')
print(f'{len(checks)} sequence checks passed; evidence: {output}',flush=True)
