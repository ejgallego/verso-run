# verso-run

**Runnable Lean examples for Verso documents.**

Write a Lean function in your document, give readers an input, and let them
choose **Run**. The document build compiles the function; a dedicated browser
worker executes it through [VIR](https://github.com/ejgallego/lean-vir).
Readers need no Lean installation. **Stop** interrupts a running example.

[![Build and test](https://github.com/ejgallego/verso-run/actions/workflows/ci.yml/badge.svg)](https://github.com/ejgallego/verso-run/actions/workflows/ci.yml)

[Demo](https://ejgallego.github.io/verso-run/) ·
[Start your own manual](examples/manual-starter/README.md) ·
[Authoring guide](docs/authoring.md)

> **Demo update:** the public MIME-compatible runtime is selected and local
> acceptance is in progress. Hosted qualification follows deployment.
> Use the local demo during this update. [Hosting details](docs/hosting.md).

![Lean computes a chain of four nodes and renders it with Illuminate](evidence/illuminate-desktop-4.png)

## Try it locally

Install [elan](https://github.com/leanprover/elan) and Python 3. The checkout selects
Lean 4.34.0 and fetches its compatible dependencies and runtime automatically.

```sh
git clone https://github.com/ejgallego/verso-run.git
cd verso-run
lake build
lake exe lean-run-demo --with-html-single --with-tex --depth 2
python3 -m http.server 8795 --bind 127.0.0.1 --directory _out/html-multi
```

Open [the greeting](http://127.0.0.1:8795/Greeting/), change its input, and choose Run.
There are a few more examples to explore:

| Example | Try |
| --- | --- |
| [Stack calculator](http://127.0.0.1:8795/Stack-calculator/) | `6 7 * 2 +`, then `5 dup *` |
| [HTML greeting](http://127.0.0.1:8795/HTML-greeting/) | A name containing `<b>&` to see text escaping |
| [Illuminate diagrams](http://127.0.0.1:8795/Illuminate-diagrams/) | `1`, `4`, and `8` nodes |
| [Exact natural numbers](http://127.0.0.1:8795/Exact-natural-numbers/) | `9007199254740993` |
| [Try Stop](http://127.0.0.1:8795/Try-Stop/) | Start a large calculation, then interrupt it |

HTML output lives in `_out/html-multi` and `_out/html-single`; TeX is in `_out/tex`.
To share a copy, see [hosting and packaging](docs/hosting.md).

## Add an example to your document

The [Manual starter](examples/manual-starter/README.md) is a small independent
project with everything wired together: a text function, a typed HTML card,
resource preparation, and a site generator. Copy it and edit its chapter.

A runnable block looks like this:

````lean
```leanRun (entry := Demo.greet) (input := "Ada")
@[vir_export]
public def Demo.greet (name : String) : String :=
  "Hello, " ++ name ++ "!"
```
````

The authoring guide explains [imports, block options, HTML, and registration](docs/authoring.md).

## What works today

| Function | Reader input | Result |
| --- | --- | --- |
| `String → String` | Text | Plain text |
| `Nat → Nat` | An exact decimal natural number | An exact decimal natural number |
| `String → Verso.Output.Html` | Text | An isolated HTML preview |

Functions must be public, executable, pure, and monomorphic, with one explicit
argument. VIR also checks their compiled dependencies. A supported function type
can still reach an operation absent from the runtime; the build will reject it.
See [troubleshooting](docs/troubleshooting.md) for examples and next steps.

This experimental release supports **Verso Manual**. Slides and blog support are
planned in [the roadmap](ROADMAP.md). Examples can use inline definitions or
[checked source anchors from imported modules](docs/authoring.md#run-an-anchored-example-from-an-imported-module).
Readers edit function inputs; source editing
belongs to the future editor work. Ordinary highlighted Lean blocks keep working,
and source remains readable without JavaScript and in TeX.

## Find your way around

- [Authoring](docs/authoring.md): runnable blocks and typed HTML.
- [Troubleshooting](docs/troubleshooting.md): unsupported programs and build/runtime errors.
- [Internals](docs/internals.md): resource ownership, execution, limits, and exact pins.
- [Contributing](CONTRIBUTING.md): build, test, and repository layout.
- [Validation](docs/validation.md): qualification scope and retained evidence.
- [Multiple genres](docs/multi-genre.md): anchor review and shared/adapter design.
- [Roadmap](ROADMAP.md): upcoming diagnostics, anchors, genres, and integration work.

The project grew from a Verso prototype; its [development history](docs/history.md)
is retained. Licensed under [Apache-2.0](LICENSE).
