"""Neutral custom-result acceptance, using the independent consumer's copied site."""
import json
from playwright.sync_api import expect


def qualify_result_presenters(page, base, prefixes, route, native, record):
    page.add_init_script('''
        window.fixtureWorkers = [];
        window.fixtureContexts = [];
        const OriginalWorker = window.Worker, OriginalAudio = window.AudioContext;
        window.Worker = class extends OriginalWorker {
            constructor(...args) { super(...args); this.retired = false; fixtureWorkers.push(this); }
            terminate() { this.retired = true; return super.terminate(); }
        };
        window.AudioContext = class extends OriginalAudio {
            constructor(...args) { super(...args); fixtureContexts.push(this); }
        };
    ''')

    def success(form):
        page.wait_for_function('e => ["success", "failed"].includes(e.dataset.state)',
                               arg=form.element_handle(), timeout=30000)
        assert form.get_attribute('data-state') == 'success', form.inner_text()

    def run(form, value):
        form.locator('input,textarea').fill(value)
        form.locator('[type=submit]').click()
        success(form)

    def packets():
        return page.locator('.lean-run').filter(has=page.locator('input'))

    for prefix in prefixes:
        url = base + prefix + '/' + route
        page.goto(url)
        page.wait_for_selector('.lean-run[data-enhanced]')
        first, second = packets().nth(0), packets().nth(1)
        for case in native:
            run(first, case['seed'])
            actual = json.loads(first.locator('.packet-value').text_content())
            assert actual == case['packet'], (actual, case['packet'])
        assert page.evaluate('fixtureContexts.length') == 0
        record(prefix + ': custom typed bytes agree with native through checked transfer; presentation creates no audio context')

        page.evaluate('''() => {
            const forms = [...document.querySelectorAll('.lean-run')];
            forms[0].id = 'first-packet'; forms[1].id = 'second-packet';
            window.resultEvents = [];
            forms[0].addEventListener('lean-run-result', e => resultEvents.push({
                state:e.detail.state, result:e.detail.result,
                visible:!forms[0].querySelector('.lean-run-result').hidden,
                text:forms[0].querySelector('.packet-value')?.textContent
            }));
        }''')
        first, second = page.locator('#first-packet'), page.locator('#second-packet')
        run(first, '255')
        event = page.evaluate('resultEvents.filter(e => e.state === "success").at(-1)')
        assert event['visible'] and json.loads(event['text']) == {'label': '255', 'bytes': [255, 0]}
        run(second, '7')
        first.get_by_role('button', name='Play', exact=True).click()
        second.get_by_role('button', name='Play', exact=True).click()
        expect(first).to_have_attribute('data-playing', 'true')
        expect(second).to_have_attribute('data-playing', 'true')
        old_instance = first.get_attribute('data-instance')
        page.evaluate('''() => {
            window.removedPacket = document.querySelector('#first-packet');
            window.packetParent = removedPacket.parentElement;
            removedPacket.remove();
        }''')
        page.wait_for_function('removedPacket.dataset.disposals === "1" && fixtureContexts[0].state === "closed"')
        assert page.evaluate('fixtureWorkers.filter(w => !w.retired).length') == 1
        expect(second).to_have_attribute('data-playing', 'true')
        page.evaluate('packetParent.append(removedPacket)')
        page.wait_for_function('removedPacket.dataset.enhanced === "true" && removedPacket.dataset.state === "idle"')
        assert first.get_attribute('data-instance') != old_instance
        expect(first.locator('.lean-run-status')).to_have_text('Ready')
        expect(first.locator('input')).to_have_value('255')
        expect(first.locator('.lean-run-result')).to_be_hidden()
        run(first, '123')
        assert first.get_attribute('data-playing') == 'false'
        mounts = first.get_attribute('data-mounts')
        instance = first.get_attribute('data-instance')
        page.evaluate('packetParent.prepend(removedPacket)')
        page.wait_for_timeout(30)
        assert first.get_attribute('data-instance') == instance
        assert first.get_attribute('data-mounts') == mounts
        assert page.evaluate('fixtureWorkers.filter(w => !w.retired).length') == 2
        record(prefix + ': removal releases worker and active media, sibling continues, reinsertion is idle, connected moves retain ownership')

        first.get_by_role('button', name='Play', exact=True).click()
        expect(first).to_have_attribute('data-playing', 'true')
        events = page.evaluate('resultEvents.filter(e => e.state === "success").length')
        page.evaluate('''() => {
            Object.defineProperty(document, 'hidden', {configurable:true, value:true});
            document.dispatchEvent(new Event('visibilitychange', {bubbles:true}));
        }''')
        expect(first).to_have_attribute('data-playing', 'false')
        page.evaluate('''() => {
            Object.defineProperty(document, 'hidden', {configurable:true, value:false});
            document.dispatchEvent(new Event('visibilitychange', {bubbles:true}));
        }''')
        expect(first.locator('.packet-value')).to_have_text(json.dumps({'label': '123', 'bytes': [123, 124]}, separators=(',', ':')))
        assert first.get_attribute('data-playing') == 'false'
        assert page.evaluate('resultEvents.filter(e => e.state === "success").length') == events
        first.get_by_role('button', name='Play', exact=True).click()
        expect(first).to_have_attribute('data-playing', 'true')
        first.locator('.lean-run-stop').click()
        expect(first).to_have_attribute('data-playing', 'false')
        assert page.evaluate('resultEvents.at(-1).result') is None
        expect(first.locator('.lean-run-result')).to_be_hidden()
        record(prefix + ': synthetic visibility pauses media with no automatic replay or duplicate success; Stop invalidates after clearing')

        text = page.locator('.lean-run').filter(has=page.locator('textarea'))
        text.locator('textarea').fill('kept\ninput')
        page.evaluate('''() => {
            window.removedText = document.querySelector('.lean-run textarea').closest('.lean-run');
            window.textParent = removedText.parentElement;
            removedText.remove();
        }''')
        page.wait_for_function('!removedText.dataset.enhanced')
        page.evaluate('textParent.append(removedText)')
        page.wait_for_function('removedText.dataset.enhanced === "true" && removedText.dataset.state === "idle"')
        expect(text.locator('textarea')).to_have_value('kept\ninput')
        text.locator('[type=submit]').click()
        success(text)
        assert json.loads(text.locator('.packet-value').text_content()) == {'label': 'kept\ninput', 'bytes': [10, 0]}
        record(prefix + ': multiline edits survive same-node retirement and submit through one fresh owner')

        # New navigation gives an uncached module graph. One placement may stop
        # waiting without cancelling another placement's shared module fetch.
        held = []
        page.route('**/lean-run/packet/render.js', lambda request: held.append(request))
        page.goto(url)
        page.wait_for_selector('.lean-run[data-enhanced]')
        first, second = packets().nth(0), packets().nth(1)
        page.evaluate('''() => {
            window.resultEvents = [];
            document.querySelector('.lean-run').addEventListener('lean-run-result', e => resultEvents.push(e.detail.state));
        }''')
        first.locator('[type=submit]').click()
        page.wait_for_function('document.querySelector(".lean-run").dataset.state === "loading view"')
        page.wait_for_timeout(20)
        assert held
        page.evaluate('''() => {
            Object.defineProperty(document, 'hidden', {configurable:true, value:true});
            document.dispatchEvent(new Event('visibilitychange', {bubbles:true}));
            Object.defineProperty(document, 'hidden', {configurable:true, value:false});
            document.dispatchEvent(new Event('visibilitychange', {bubbles:true}));
        }''')
        for request in held:
            request.continue_()
        success(first)
        assert page.evaluate('resultEvents.filter(s => s === "success").length') == 1
        expect(first.locator('.lean-run-result')).to_be_visible()
        assert page.evaluate('fixtureContexts.length') == 0
        page.unroute('**/lean-run/packet/render.js')
        record(prefix + ': hiding during first renderer import preserves the completed result and emits initial success once after show')

        page.route('**/lean-run/packet/render.js', lambda request: held.append(request))
        held.clear()
        page.goto(url)
        page.wait_for_selector('.lean-run[data-enhanced]')
        first, second = packets().nth(0), packets().nth(1)
        first.locator('[type=submit]').click()
        page.wait_for_function('document.querySelector(".lean-run").dataset.state === "loading view"')
        page.wait_for_timeout(20)
        assert held
        first.locator('.lean-run-stop').click()
        expect(first).to_have_attribute('data-state', 'stopped')
        second.locator('[type=submit]').click()
        for request in held:
            request.continue_()
        success(second)
        expect(first).to_have_attribute('data-state', 'stopped')
        expect(first.locator('.lean-run-result')).to_be_hidden()
        first.locator('[type=submit]').click()
        success(first)
        page.unroute('**/lean-run/packet/render.js')
        record(prefix + ': held renderer Stop settles before release, late completion cannot mount, sibling and explicit retry work')
