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

The pinned runtime accepts both `text/javascript` and `application/javascript`
for JavaScript assets and requires `application/wasm` for Wasm. It also checks
downloaded files against the published inventory. Earlier hosted acceptance
results are recorded in [validation history](validation.md#current-qualification).

Run `uv run --with playwright python tests/pages-smoke.py` after deployment to
compare the hosted site with a fresh local build. Regenerate local output first:
the check rejects differences between the hosted and local program/runtime
inventories. Local build checks and hosted acceptance are recorded separately.

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
