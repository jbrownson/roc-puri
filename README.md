# Puri for Roc

Puri (pronounced “pure-eye”) is an experiment in immediate, renderer- and
layout-independent user interfaces for Roc. Applications own their state and
describe widgets afresh each frame; placing a widget performs drawing and
produces one-shot event handling without constructing a retained widget tree.

This source workspace contains Puri, a continuation-based port of Clay's layout
behavior named Roclay, their supporting packages, a narrow native platform
facade, and a complete Todo example.

## Status

This is an experimental design prototype, not a released Roc package. Its APIs
are expected to change as the design is discussed and tested.

The implementation targets nightlies of the new Zig-based Roc compiler—not the
older alpha4 compiler—and was last verified with the 2026-07-25 nightly:

```text
Roc compiler version release-fast-b6cdced9
```

The native example and executable test hosts currently support macOS on Apple
Silicon and Intel. The Puri, Geometry, and Roclay source is not inherently
macOS-specific.

[`ROC_NOTES.md`](ROC_NOTES.md) records compiler limitations, platform friction,
and language-design questions encountered while developing the workspace.

## Projects

- [`geometry`](geometry) — generic 2D geometry shared by the libraries.
- [`roclay`](roclay) — a continuation-based port of Clay 0.14's layout
  behavior.
- [`puri`](puri) — renderer- and layout-independent immediate UI components.
- [`puri-roclay`](puri-roclay) — the optional integration package connecting
  Puri widgets to Roclay layouts.
- [`roc-ray-platform`](roc-ray-platform) — the narrow RocRay/Raylib platform
  facade and native adapter used by the example.
- [`todo`](todo) — a complete native example built from the other five
  projects.

```text
geometry
  ↑      ↑
puri  roclay
  ↑      ↑
  puri-roclay
       ↑
      todo ← roc-ray-platform
```

Roc package and platform dependencies use sibling-relative paths, for example:

```roc
{
    geometry: "../geometry/main.roc",
}
```

If these directories become separate repositories, those strings are the
places to substitute published package URLs. No source module relies on the
workspace root or a shared test directory.

## Requirements

- the Roc nightly shown above, or a compatible newer Zig-compiler nightly
  installed using Roc's
  [official instructions](https://www.roc-lang.org/install/) and available as
  `roc` on `PATH`;
- macOS and the Xcode Command Line Tools for native builds;
- `make`, a C compiler, `curl`, and `tar`;
- Python 3 only for Roclay's generated conformance tests, fuzzing, and reducer.

The first native build downloads RocRay's pinned 0.8.0 host bundle. The URL,
version, and extracted inputs are controlled by
[`roc-ray-platform/Makefile`](roc-ray-platform/Makefile); downloads and build
products remain ignored.

## Running the example

The root Makefile exists only for the integrated application and workspace
cleanup:

```sh
make run
# Equivalent: make native-run
make clean
```

`make run` delegates to Todo's native target, whose own dependency graph
prepares the RocRay adapter and rebuilds when the application, platform, or
library sources change. Run development commands from the project that owns
them—for example, `make test` in `puri`, `make fuzz-tree` in `roclay`, or
`make native-headless` in `todo`. Build products and compiler caches stay
inside that project.

## Suggested reading order

1. Geometry foundations:
   [`geometry/Geometry2d.roc`](geometry/Geometry2d.roc), then
   [`puri/Geometry.roc`](puri/Geometry.roc).

2. Puri's composition model:
   [`Handler`](puri/Handler.roc), [`Canvas`](puri/Canvas.roc), and
   [`Frame`](puri/Frame.roc).

3. A small standard component:
   [`Button`](puri/Button.roc), consulting [`Event`](puri/Event.roc) as its
   input types arise. The other standard components follow the same pattern.

4. Text editing:
   [`LineEditing`](puri/LineEditing.roc), the concise pure engine, followed by
   the chrome-free [`EditableText`](puri/EditableText.roc) leaf. Treat
   [`LineEditingInternal`](puri/LineEditingInternal.roc),
   [`Utf8`](puri/Utf8.roc), and [`CaretMap`](puri/CaretMap.roc) as optional
   implementation detail.

5. Layout:
   [`Roclay`](roclay/Roclay.roc). Treat
   [`RoclayInternal`](roclay/RoclayInternal.roc) as implementation detail
   unless the solver is of interest.

6. The Puri–Roclay bridge:
   [`Layout`](puri-roclay/Layout.roc), the standard-widget
   [`adapters`](puri-roclay/Widgets.roc)—including `EditableText` as an
   ordinary leaf—then [`Frame`](puri-roclay/Frame.roc).

7. The application:
   [`Todo`](todo/Todo.roc), [`TodoFocus`](todo/TodoFocus.roc),
   [`TodoUi`](todo/TodoUi.roc), and [`main`](todo/main.roc).

Each project README describes its own API and verification strategy in more
detail.

## Development provenance

The design was directed and reviewed by Jake Brownson. Much of the
implementation was produced through iterative collaboration with OpenAI Codex
(GPT-5.6), including executable tests and repeated manual review. Roclay is
also checked against Clay 0.14 by deterministic generated conformance cases
and fuzzing.

## License

Original work in this repository is available under the
[Universal Permissive License, Version 1.0](LICENSE). See
[`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md) for Clay, RocRay, and
raylib attribution and license notices.
