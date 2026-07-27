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

1. [`geometry/Geometry2d.roc`](geometry/Geometry2d.roc)
2. [`puri/Handler.roc`](puri/Handler.roc)
3. [`puri/Canvas.roc`](puri/Canvas.roc)
4. [`puri/Frame.roc`](puri/Frame.roc)
5. Puri's standard components, starting with
   [`puri/Button.roc`](puri/Button.roc); consult
   [`puri/Event.roc`](puri/Event.roc) as its input types arise
6. [`puri/LineEdit.roc`](puri/LineEdit.roc) and
   [`puri/LineEditWidget.roc`](puri/LineEditWidget.roc)
7. [`roclay/Roclay.roc`](roclay/Roclay.roc), treating
   [`roclay/RoclayInternal.roc`](roclay/RoclayInternal.roc) as implementation
   detail unless the solver is of interest
8. The small [`puri-roclay`](puri-roclay/Layout.roc) bridge, including its
   standard-widget [`adapters`](puri-roclay/Widgets.roc)
9. [`todo/Todo.roc`](todo/Todo.roc), [`todo/TodoFocus.roc`](todo/TodoFocus.roc),
   [`todo/TodoUi.roc`](todo/TodoUi.roc), and [`todo/main.roc`](todo/main.roc)

Each project README describes its own API and verification strategy in more
detail.
