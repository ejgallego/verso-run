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
The generated paths are relative, and worker execution at nested prefixes is
covered by acceptance checks. No generated site files are committed to Git.


## Current hosting limitation

The site is deployed, but Run currently fails on GitHub Pages: its server sends
`application/javascript`, and the frozen VIR loader requires `text/javascript`.
The local Python server works. A VIR fix and matching runtime have been qualified
by their owner locally; downstream adoption awaits exact source publication and
an explicitly selected public runtime release. Do not substitute unpublished
packs or alter generated manifests. See [the roadmap](../ROADMAP.md).

## Share a complete copy

After generating the demo, run:

```sh
python3 scripts/package-demo.py
```

This produces `_out/verso-run-demo.zip`. Recipients can unpack it and run
`python3 -m http.server 8795 --directory verso-run-demo`, then open `/Greeting/`.
They need no Lean installation. Serve the whole site over HTTP, including all
`lean-run/` resources. Root and nested copied deployments are covered by tests.
Hosts must serve JavaScript as `text/javascript` for the current frozen runtime.
