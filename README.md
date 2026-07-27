# Puri for Roc workspace

This workspace contains six related Roc projects developed together while the
APIs are still moving. Each top-level project owns its source, tests,
documentation, build outputs, and test support so it can later become an
independent repository.

The implementation targets recent nightlies of the new Zig-based Roc compiler
and was last verified with the 2026-07-25 nightly,
`release-fast-b6cdced9`.

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

## Workspace commands

Install a recent Roc nightly and make `roc` available on `PATH`. The root
Makefile exists only for the integrated application and workspace cleanup:

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
   [`Layout`](puri-roclay/Layout.roc), standard-widget
   [`adapters`](puri-roclay/Widgets.roc), [`Frame`](puri-roclay/Frame.roc),
   then the composed [`LineEdit`](puri-roclay/LineEdit.roc).

7. The application:
   [`Todo`](todo/Todo.roc), [`TodoFocus`](todo/TodoFocus.roc),
   [`TodoUi`](todo/TodoUi.roc), and [`main`](todo/main.roc).

Each project README describes its own API and verification strategy in more
detail.
