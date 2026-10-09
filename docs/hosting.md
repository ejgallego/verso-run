# Hosting and sharing

Enable Pages at <https://github.com/ejgallego/verso-run/settings/pages> by selecting
**GitHub Actions** under **Build and deployment → Source**. Then run the
[Build and test workflow](https://github.com/ejgallego/verso-run/actions/workflows/ci.yml)
on `main`, or rerun its latest run. GitHub's
[custom-workflow documentation](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)
describes this publishing source.

CI uploads the generated `_out/html-multi` site only after the build, demo
acceptance, independent starter, and packaging succeed. A separate Pages job
deploys that artifact on `main`; pull requests validate without deployment.
If Pages is not configured yet, the job skips deployment and prints the settings
link. Enable the Actions publishing source and rerun the workflow when ready.

The project URL is <https://ejgallego.github.io/verso-run/>.
Try `/Stack-calculator/`, `/HTML-greeting/`, or `/Illuminate-diagrams/` beneath it.
The landing page also links to `/blog/page/` and a runnable dated Blog post.
The `/slides/` deck uses the same runtime with native Reveal assets.
The generated paths are relative, and worker execution at nested prefixes is
covered by acceptance checks. No generated site files are committed to Git.


## Runtime MIME compatibility and acceptance

The old frozen loader rejected GitHub Pages' `application/javascript` response
for assets declared `text/javascript`. The selected runtime `6cddc4b8…` accepts
that equivalent JavaScript spelling while preserving file/manifest integrity and
Wasm MIME checks. Actual Pages acceptance verified Greeting, exact Nat, escaped
HTML, and Illuminate SVG against native Lean, with the hosted publication equal
to the validated local plan. Runtime JavaScript responses used
`application/javascript`. Retained [hosted qualification history](validation.md#current-results-and-historical-evidence)
record the publication and MIME responses.

Run `uv run --with playwright python tests/pages-smoke.py` after deployment to
repeat the source-inspected hosted harness. Regenerate local output first; this
check deliberately rejects a different hosted program/runtime publication.

## Share a complete copy

Generate the combined landing, Manual, Blog, and Slides site, then package it:

```sh
python3 scripts/build-demo-site.py
python3 scripts/package-demo.py
```

This produces `_out/verso-run-demo.zip`. Recipients can unpack it and run
`python3 -m http.server 8795 --directory verso-run-demo`, then open `/`.
They need no Lean installation. Serve the whole site over HTTP, including all
`lean-run/` resources. Root and nested copied deployments are covered by tests.
Serve JavaScript as `text/javascript` or `application/javascript`, and Wasm as
`application/wasm`, with the complete published inventory.
