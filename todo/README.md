# Puri todo

This native todo application is the end-to-end example for Geometry2d, Roclay,
Puri, the Puri–Roclay integration, and the local RocRay platform facade. It is
an application project rather than part of any reusable package.

It deliberately demonstrates the simplest Puri state-management layer: task
data, focus, text selections, editing state, and scroll position are ordinary
fields in one application model. The app uses neither a retained widget tree
nor an identity-keyed state store; those are alternative layers that could
drive the same Puri controls.

## Structure

- [`Todo.roc`](Todo.roc) contains pure model transitions.
- [`TodoFocus.roc`](TodoFocus.roc) defines this application's optional keyboard
  focus domain and Tab order.
- [`TodoUi.roc`](TodoUi.roc) is the page-level composition.
- [`TodoTaskRow.roc`](TodoTaskRow.roc) contains task-specific
  edit/toggle/delete behavior.
- [`TodoTheme.roc`](TodoTheme.roc) binds Puri components and Puri–Roclay
  compositions to RocRay fonts and colors.
- [`RocRayCanvas.roc`](RocRayCanvas.roc) and
  [`RocRayInput.roc`](RocRayInput.roc) are platform adapters.
- [`main.roc`](main.roc) owns only initialization and the per-frame loop.
- [`TodoTests.roc`](TodoTests.roc) and [`tests/platform`](tests/platform) are
  self-contained model tests.

The app header references all reusable projects through sibling-relative paths.
Those entries can be replaced with package URLs if the projects move to
separate repositories.

## Features

Tasks can be added, toggled, edited, deleted, and scrolled. Edit/Done controls
editing explicitly, and double-clicking a task label enters editing directly.
The line editor
supports selection, dragging, word and line navigation, standard macOS
copy/cut/paste chords, and horizontal scrolling. Tab and Shift-Tab traverse
controls according to an order defined by `TodoFocus`; Enter submits;
Escape clears focus; Cmd-Q quits. Committing an empty or whitespace-only task
edit deletes that task, while nonempty edits are trimmed.

The draft starts focused. The task list clips and scrolls with a wheel or
high-resolution trackpad. Puri itself neither stores focus nor defines a
traversal policy; this application uses an explicit focus enum and handles Tab
as an ordinary key event.

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

The RocRay snapshot may report several input changes in one native frame. This
small adapter offers at most one event to Puri's one-shot handler, with pointer
button changes before dragging, scrolling, and keys. A production integration
could redraw and rebuild a handler between queued events.

On macOS, Magnet's “Snap windows by dragging” feature can make Raylib miss
short clicks. Disable that feature or quit Magnet while using the demo.
