# Puri todo

This native todo application is the end-to-end example for Geometry2d, Roclay,
Puri, the Puri–Roclay integration, and the local RocRay platform facade. It is
an application project rather than part of any reusable package.

It deliberately demonstrates the simplest Puri state-management layer: task
data, focus, text selections, editing state, and scroll position are ordinary
fields in one application model. The app uses neither a retained widget tree
nor an identity-keyed state store; those are alternative layers that could
drive the same Puri controls.

Task rows have no stable IDs. Their one-shot handlers capture current list
indices, while model transitions explicitly shift or clear longer-lived index
references such as editing and focus when the list changes.

## Structure

- [`Todo.roc`](Todo.roc) contains pure model transitions.
- [`TodoFocus.roc`](TodoFocus.roc) constructs this application's explicit Tab
  order for Puri's optional `KeyboardFocus` widget.
- [`TodoUi.roc`](TodoUi.roc) is the page-level composition.
- [`TodoTaskRow.roc`](TodoTaskRow.roc) contains task-specific
  edit/toggle/delete behavior and places the drag handle supplied by
  Puri–Roclay's reusable `ReorderableList`.
- [`TodoTheme.roc`](TodoTheme.roc) binds Puri components and Puri–Roclay
  compositions to RocRay fonts and colors.
- [`RocRayCanvas.roc`](RocRayCanvas.roc) and
  [`RocRayInput.roc`](RocRayInput.roc) are platform adapters kept app-local by
  the package/platform limitation documented in
  [`ROC_NOTES.md`](../ROC_NOTES.md).
- [`main.roc`](main.roc) owns only initialization and the per-frame loop.
- [`TodoTests.roc`](TodoTests.roc) and [`tests/platform`](tests/platform) are
  self-contained model tests.

The app header references all reusable projects through sibling-relative paths.
Those entries can be replaced with package URLs if the projects move to
separate repositories.

## Features

Tasks can be added, toggled, edited, deleted, scrolled, and reordered by their
grip handles. A drag moves only a transient gap and floating rendering; task
order, editing references, and focus references change together on drop.
Edit/Done controls editing explicitly, and double-clicking a task label enters
editing directly. A checkbox and its label form one keyboard-focusable control:
clicking the box toggles it immediately, while the first label click focuses
the control immediately without changing its completion state. The second
label click enters editing with the caret at the clicked text position. A
small pointer-move hysteresis filter prevents the label-to-editor layout change
from turning that click into an accidental selection drag, while holding and
moving the same click still selects text normally. The rest of the active click
run is offset into the editor's frame of reference, so a third physical click
is its logical double click rather than an inherited triple click. That
unusually fine-grained transition is possible because the interaction state
and one-shot handlers are explicit rather than hidden behind the identities of
two retained widgets.
The line editor supports selection, dragging, word and line navigation,
standard macOS copy/cut/paste chords, and horizontal scrolling. Tab and
Shift-Tab traverse controls according to an order defined by `TodoFocus`;
Enter submits; Escape clears focus; Cmd-Q quits. Committing an empty or
whitespace-only task edit deletes that task, while nonempty edits are trimmed.

The draft starts focused. The task list clips and scrolls with a wheel or
high-resolution trackpad. Puri itself neither stores focus nor defines a
traversal policy; this application uses an explicit focus enum and supplies
its order to a stateless widget that handles traversal and fallback clearing as
ordinary input events.

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

`native-run` uses Roc's quick development backend; `native-speed-run` uses the
optimized LLVM backend and currently takes about 16 seconds and 900 MB to
build on an M-series Mac. The latter is much better than older nightlies,
which exhausted memory while specializing this application.

The pinned RocRay 0.9 host uses Zig's `smp_allocator` for ordinary runs. This
upstreams the roughly 45× host-side improvement found while profiling the
earlier 0.8-based demo; the root README records that history and its limits.

[`ROC_NOTES.md`](../ROC_NOTES.md) records the resolved build pathology and the
compiler crash discovered while verifying its fix.

RocRay 0.9 exposes entered Unicode codepoints in active-keyboard-layout order,
which this demo translates directly into Puri character events. Puri's editor
core is UTF-8 safe; complete input-method preedit and grapheme-aware editing
remain future work.

The RocRay snapshot may report several input changes in one native frame. This
adapter preserves every supported change in deterministic pointer, scroll, then
key order. The host snapshot cannot recover the actual chronology of
simultaneous changes. Todo gives each event a freshly laid-out Puri frame and
one-shot handler; frames before the final event use Puri's silent Canvas, so
they execute complete layout and placement without drawing. Every translated
event carries the host's monotonic timestamp; when no input occurred,
`EventLoop` supplies one `TimePassed` event instead.

On macOS, Magnet's “Snap windows by dragging” feature can make Raylib miss
short clicks. Disable that feature or quit Magnet while using the demo.
