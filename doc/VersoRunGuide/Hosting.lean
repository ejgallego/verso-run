module
public import VersoManual
open Verso Genre Manual

#doc (Manual) "Hosting and sharing" =>

%%%
tag := "guide-hosting"
file := "hosting"
%%%

A published verso-run document is a static website. Readers need a browser,
not a Lean installation or a server that runs Lean. Copy the complete generated
HTML directory to the web host, including its `lean-run/` resources and other
assets.

# Preview locally
%%%
tag := "guide-hosting-preview-locally"
%%%

For a Manual generated under `_out/html-multi`, start a local server:

```
python3 -m http.server 8795 --bind 127.0.0.1 --directory _out/html-multi
```

Open [http://127.0.0.1:8795/](http://127.0.0.1:8795/) in a browser.
For Blog or Slides, use the output directory selected in the generator instead.
Serve the site over HTTP; opening an HTML file directly is not sufficient for
worker execution.

# Publish on a web host
%%%
tag := "guide-hosting-publish-on-a-web-host"
%%%

Upload the complete output directory to a static web host. Keep the generated
relative paths intact. The site can live at the domain root or under a URL prefix.

JavaScript files must be served as `text/javascript` or `application/javascript`,
and Wasm files as `application/wasm`. The runtime checks the downloaded files
against their published inventory. A missing resource or an incorrect MIME type
appears as a loading error in the example; replacing only `index.html` does not
update its compiled program.

GitHub Pages is one possible host. In the repository's Pages settings, select
*GitHub Actions* as the source, then configure a workflow to build the document
and deploy its complete HTML output. GitHub's
[custom-workflow documentation](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)
describes that setup.

# Share a complete copy
%%%
tag := "guide-hosting-share-a-complete-copy"
%%%

A copy can be shared as a directory or an archive. Recipients can unpack it,
start an HTTP server in that directory, and run the examples without building
Lean. Include all files from the generated HTML output.

This repository's demo combines the Manual, Blog, Slides, user guide, and API
reference. To package that combined site:

```
python3 scripts/build-demo-site.py
python3 scripts/package-demo.py
```

The result is `_out/verso-run-demo.zip`. After unpacking, serve it with
`python3 -m http.server 8795 --directory verso-run-demo` and open `/`.
