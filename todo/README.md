# Puri todo

This native todo application is the end-to-end example for Geometry2d, Roclay,
Puri, the Puri–Roclay integration, and the local RocRay platform facade. It is
an application project rather than part of any reusable package.

## Structure

- [`Todo.roc`](Todo.roc) contains pure model transitions.
- [`TodoUi.roc`](TodoUi.roc) is the page-level composition.
- [`TodoTaskRow.roc`](TodoTaskRow.roc) contains task-specific
  edit/toggle/delete behavior.
- [`TodoTheme.roc`](TodoTheme.roc) binds standard Puri components to RocRay
  fonts and colors.
- [`PuriCanvasRocRay.roc`](PuriCanvasRocRay.roc) and
  [`PuriInputRocRay.roc`](PuriInputRocRay.roc) are platform adapters.
- [`main.roc`](main.roc) owns only initialization and the per-frame loop.
- [`TodoTests.roc`](TodoTests.roc) and [`tests/platform`](tests/platform) are
  self-contained model tests.

The app header references all reusable projects through sibling-relative paths.
Those entries can be replaced with package URLs if the projects move to
separate repositories.

## Features

Tasks can be added, toggled, edited, deleted, and scrolled. The line editor
supports selection, dragging, word and line navigation, standard macOS
copy/cut/paste chords, and horizontal scrolling. Tab and Shift-Tab traverse
controls; Enter submits; Escape clears focus; Cmd-Q quits.

The draft starts focused. The task list clips and scrolls with a wheel or
high-resolution trackpad, and focus traversal reveals offscreen controls.

## Commands

```sh
make check
make test
make native-headless
make native-run
make native-speed-run
```

The first native build asks the sibling
[`roc-ray-platform`](../roc-ray-platform) project to download and prepare its
pinned upstream binaries. Subsequent `make native-run` calls rebuild only when
the todo, library, or platform sources are newer than the executable.

RocRay does not expose a platform text-input queue, so this demo currently maps
US keyboard positions to ASCII. Puri's editor core is UTF-8 safe, but
keyboard-layout-aware Unicode and IME input require a richer platform event
surface.

On macOS, Magnet's “Snap windows by dragging” feature can make Raylib miss
short clicks. Disable that feature or quit Magnet while using the demo.
