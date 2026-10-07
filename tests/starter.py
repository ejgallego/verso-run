"""Build the copyable starter from Git and exercise its published Wasm worker."""
import argparse
import functools
import http.server
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument("--output", default="_out/starter-acceptance")
args = parser.parse_args()
output = Path(args.output).resolve()
output.mkdir(parents=True, exist_ok=True)
project = Path(tempfile.mkdtemp(prefix="verso-run-starter-"))
shutil.copytree(ROOT / "examples/manual-starter", project, dirs_exist_ok=True,
                ignore=shutil.ignore_patterns(".lake", ".vir-generated", "_out"))
checks = []


def record(name):
    checks.append({"test": name, "result": "pass"})
    print("PASS", name, flush=True)


def command(args, log):
    with (output / f"{log}.log").open("w") as stream:
        result = subprocess.run(args, cwd=project, stdout=stream, stderr=subprocess.STDOUT)
    if result.returncode:
        raise RuntimeError(f"{args} failed: see {output / f'{log}.log'}")


assert not (project / ".lake").exists()
command(["lake", "--no-cache", "build"], "build")
manifest = json.loads((project / "lake-manifest.json").read_text())
assert all(package["type"] == "git" for package in manifest["packages"])
extension = next(package for package in manifest["packages"] if package["name"] == "verso_run")
assert extension["url"] == "https://github.com/ejgallego/verso-run"
expected = json.loads((ROOT / "examples/manual-starter/lake-manifest.json").read_text())
expected_revision = next(p["rev"] for p in expected["packages"] if p["name"] == "verso_run")
assert extension["rev"] == expected_revision
assert subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=project/".lake/packages/verso_run", text=True).strip() == expected_revision
vir = next(p for p in manifest["packages"] if p["name"] == "lean_vir")
assert vir["rev"] == "bda79d5c4ab7d061c971fcd8917f536393ec03ee"
import hashlib
runtime_pack = project / ".lake/packages/lean_vir/.vir-generated/VirResourceRuntime.virres"
assert hashlib.sha256(runtime_pack.read_bytes()).hexdigest() == "3910c29e40ee68c3b110355fa1d30dae3029f2b34967269642521fc8409848d7"
assert not any(path.is_symlink() for path in (project / ".lake/packages").iterdir())
record("cold no-cache starter acquires the exact public extension and runtime with Git dependencies and no seeds/symlinks")
command(["lake", "exe", "starter-manual", "--with-html-single", "--with-tex", "--depth", "2"],
        "generate")
site = project / "_out"
plan = json.loads((site / "html-multi/lean-run/publication.json").read_text())
bindings = plan["programs"]["Starter.Chapter"]
assert set(bindings) == {"Starter.greet", "Starter.card.leanRunHtml"}
assert all(binding["expectedExport"]["effect"] == "pure"
           for binding in bindings.values())
assert json.loads((site / "html-single/lean-run/publication.json").read_text()) == plan
record("text and typed HTML exports retain compiler contracts in both layouts")
tex = (site / "tex/main.tex").read_text()
assert "Starter.greet" in tex and "Starter.card" in tex
record("TeX retains both examples' source")


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *_):
        pass


served = output / "served"
for destination in [served / "root", served / "verso-run/starter"]:
    shutil.copytree(site / "html-multi", destination, dirs_exist_ok=True)
server = http.server.ThreadingHTTPServer(("127.0.0.1", 0),
    functools.partial(QuietHandler, directory=str(served)))
threading.Thread(target=server.serve_forever, daemon=True).start()
base = f"http://127.0.0.1:{server.server_port}/"
try:
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True,
                                            executable_path=shutil.which("google-chrome"))
        try:
            page = browser.new_page()
            errors = []
            page.on("pageerror", lambda error: errors.append(str(error)))

            def run(form, value):
                form.locator("input").fill(value)
                form.locator('[type="submit"]').click()
                page.wait_for_function(
                    "e => ['success', 'failed'].includes(e.dataset.state)",
                    arg=form.element_handle(), timeout=20000)
                assert form.get_attribute("data-state") == "success", form.inner_text()

            for prefix in ["root", "verso-run/starter"]:
                page.goto(base + prefix + "/Greeting/")
                page.wait_for_selector(".lean-run[data-enhanced]")
                greeting = page.locator('.lean-run[data-experiment*="Starter.greet"]')
                assert greeting.locator("input").input_value() == "Ada"
                run(greeting, "世界 😀")
                assert greeting.locator(".lean-run-output").text_content() == "Hello, 世界 😀!"
                record(f"{prefix}: edited Unicode greeting runs in the Wasm worker")

                page.goto(base + prefix + "/HTML-card/")
                page.wait_for_selector(".lean-run[data-enhanced]")
                card = page.locator('.lean-run[data-experiment*="Starter.card.leanRunHtml"]')
                run(card, '<b>& "Ada" 😀')
                frame = card.frame_locator("iframe")
                assert frame.locator("h2").text_content().strip() == 'Hello, <b>& "Ada" 😀!'
                assert frame.locator("b").count() == 0
                assert "&lt;b&gt;&amp;" in card.locator("iframe").get_attribute("srcdoc")
                assert card.locator("iframe").get_attribute("sandbox") == ""
                record(f"{prefix}: typed HTML escapes edited input in an isolated preview")
                card.locator("input").fill("Grace")
                assert card.locator("iframe").is_hidden()
                run(card, "Grace")
                assert frame.locator("h2").text_content().strip() == "Hello, Grace!"
                record(f"{prefix}: input edits clear the preview and allow a fresh call")

            assert not errors, errors
            record("browser reports no uncaught page errors")
            context = browser.new_context(java_script_enabled=False)
            plain = context.new_page()
            plain.goto(base + "root/Greeting/")
            assert "public def Starter.greet" in plain.locator("body").inner_text()
            assert plain.locator('.lean-run [type="submit"]').is_disabled()
            assert plain.locator(".lean-run noscript").count() == 1
            context.close()
            record("no-JavaScript output retains source and disabled Run controls")
        finally:
            browser.close()
finally:
    server.shutdown()
    server.server_close()

(output / "results.json").write_text(json.dumps({"checks": checks, "publication": plan,
    "project": str(project), "dependencyRevision": extension["rev"]}, indent=2) + "\n")
print(f"{len(checks)} starter checks passed; evidence: {output}", flush=True)
