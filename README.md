# Puri for Roc

This repository is an in-progress Roc port of Puri and its
continuation-based layout companion, Halay. The first milestone is Roclay: a
small layout library whose geometry matches Clay 0.14, but whose public API
exposes measurement and placement continuations instead of render commands.

The implementation targets the new Zig-based Roc compiler and is currently
pinned to `release-fast-afef9119`.

## Current slice

- [`Geometry2d`](src/Geometry2d.roc) provides renderer-independent geometry.
  Its `Point`, `Size`, `Rect`, `Insets`, and `Placement` types are generic in
  the scalar; Roclay specializes them to `F32` for Clay and graphics-API
  compatibility. A placement carries only the settled layout rectangle;
  drawing bounds and event policy belong to the callback or a controlled
  container, not to Roclay.
- [`Roclay`](src/Roclay.roc) implements rows, columns, padding, gaps, fit,
  fixed, fill, percent, min/max constraints, alignment, aspect ratio, clips,
  child offsets, intrinsic leaves, width-sensitive text, decorators, and
  controlled containers.
- [`RoclayPlacementTests`](src/RoclayPlacementTests.roc) checks 16 fixed Clay
  placements plus a Roclay-specific controlled container that calls its
  `place_kids!` continuation.
- [`clay_oracle.c`](oracle/clay_oracle.c) and the vendored Clay 0.14 header are
  the independent behavioral oracle. See [`oracle/README.md`](oracle/README.md).
- Deterministic generators cover flat containers, recursive trees, and text.
  Recursive trees mix intrinsic and text leaves, so wrapping is exercised
  under nested sizing, clipping, offsets, and aspect ratios.
- [`PuriHandler`](src/PuriHandler.roc) provides transient, composed event
  channels and a compositional per-frame focus traversal summary;
  [`PuriCanvas`](src/PuriCanvas.roc) is the direct-call rendering dictionary;
  and [`Puri`](src/Puri.roc) threads both through placement.
- [`PuriLineEdit`](src/PuriLineEdit.roc) provides pure UTF-8 editing
  transitions over independently supplied text and selection values,
  including character/word motion and deletion, selection extension,
  multi-click selection, and clipboard commands.
  [`PuriLineEditWidget`](src/PuriLineEditWidget.roc) consumes an ephemeral
  per-frame description, renders it, then registers pointer/key handlers
  against the settled Roclay placement.
- [`PuriButton`](src/PuriButton.roc) ports Puri's generic button interaction:
  drawing is caller-supplied, focus is explicit, and pointer, Enter, and Space
  activation all dispatch directly into application transitions.
  [`PuriCheckbox`](src/PuriCheckbox.roc) is a styled specialization built on
  that generic button rather than a stateful control implementation.
- [`PuriFrame`](src/PuriFrame.roc) provides pure visual chrome around any
  layout: padding plus an optional background and inset border, drawn directly
  through the caller's canvas.
- [`PuriCanvasRecording`](src/PuriCanvasRecording.roc) is the initial
  interpreter used by tests. Production canvases do not build commands.
- [`PuriCanvasRocRay`](src/PuriCanvasRocRay.roc) is a direct native interpreter
  over RocRay/Raylib, and [`PuriRocRayDemo`](src/PuriRocRayDemo.roc) is an
  interactive todo slice on the new Roc compiler. Tasks can be added, toggled,
  and deleted; [`PuriTodo`](src/PuriTodo.roc) keeps that example's pure model
  transitions separate from its ephemeral widget descriptions.

Roclay necessarily owns a constraint tree because parent and child sizes must
be solved together. Rendering remains finally tagless: after measurement,
leaf and decorator callbacks receive final placements and act immediately.
The callback state is explicit and generic:

```roc
Place(state) : state, Placement => state
PlaceKids(state) : state, Point => state
PlaceContainer(state) : state, Placement, ContainerInfo, PlaceKids(state) => state
MeasureText : Str => Size
PlaceTextLine(state) : state, U64, Str, Placement => state
```

A production state can carry a renderer and event handler. The test state is
only a list of recorded placements, giving us an initial encoding at the
testing boundary without imposing one on renderers.

`Roclay.text!` calls the supplied measurement function while constructing the
layout, wraps after horizontal sizes are resolved, and calls `place_line!`
with each final line. Text rendering is therefore direct too; Roclay does not
return a list of render commands.

Puri uses the same first-order dictionary pattern in place of Rust traits or
Haskell typeclasses. `PuriCanvas.Canvas(render, paint)` is a record of effect
functions such as `fill_rect!`, `fill_text!`, and scoped `with_clip!`. A
`Puri.Frame` carries the renderer plus the transient handler assembled during
placement.

A widget argument is just the data required to describe this frame, not a
retained object or a prescribed application-model shape. An application can
store text and selection separately, derive either one, or construct an
entirely new line-edit value every frame. Puri has no global focused-control
or hidden text-box state.

## Build and test

The bootstrapping compiler lives at `.tools/roc/bin/roc` and is intentionally
ignored by git. `.roc-version` records the exact build. Put another compatible
new-compiler binary at that path or override `ROC=/path/to/roc`.

```sh
make check
make test
make conformance
make puri-test
make specialization-repro
make fuzz-flat
make fuzz-tree
make fuzz-text
make oracle
make native-headless
make native-run
make native-speed-run
```

The fuzz targets are deterministic and save their replayable input under
`build/`. Their case counts and seeds can be overridden, for example:

```sh
make fuzz-text TEXT_FUZZ_CASES=1000 TEXT_FUZZ_SEED=1
make fuzz-tree TREE_FUZZ_CASES=250 TREE_FUZZ_SEED=2
```

If a recursive case fails, the greedy reducer can reconstruct it from its
seed and one-based case number, then repeatedly compile smaller candidates
while preserving a chosen rectangle-delta band:

```sh
python3 tools/reduce_tree_conformance.py \
  --seed 402607220048 --case 35 \
  --min-delta 0.5 --max-delta 0.85
```

The generated single-case Roc program and Clay wire input are written under
`src/RoclayTreeReduced*.roc` and `build/`; both are ignored so reductions do
not disturb the normal generated corpus.

`make conformance` currently supports native Apple Silicon and Intel macOS. It
builds a deliberately tiny C platform in [`test-platform`](test-platform) so
the effectful continuation tests do not depend on basic-cli or RocRay.

`make specialization-repro` preserves a small compiler-performance comparison
for Roclay's callback-parameterized state. See
[`compiler-repro/README.md`](compiler-repro/README.md) for measurements. It is
not part of the normal test or native-run targets.

[`compiler-repro/loop-carried-binder`](compiler-repro/loop-carried-binder)
contains a minimized optimizer correctness bug, cross-target results, and a
prepared upstream issue report. It is also separate from normal project tests.

## Native RocRay demo

`make native-run` downloads the pinned RocRay 0.8 platform bundle, reuses its
prebuilt Zig/Raylib 6 host, builds `PuriRocRayDemo` in Roc's development mode,
and opens a resizable native window. `make native-headless` builds the same
executable and exercises three frames through RocRay's headless host mode,
which is suitable for CI.

Make skips the native compiler when the executable is newer than all Roc
sources. When a rebuild is needed, the recipe disables Roc's internal compiler
cache and writes to a temporary output before atomically replacing the runnable
binary. This guards against stale or partial executables while the pinned new
compiler is still under development.

The pinned compiler's speed optimizer currently miscompiles this demo: after a
task is added, its row may be omitted or laid out past the window edge. The
normal native targets therefore use `--opt=dev`, which also rebuilds much
faster. `make native-speed-run` keeps the optimized behavior available as an
explicit compiler-bug reproducer without replacing the working development
binary.

Click the text field, type a task, and press Enter to add it. Its editing follows
desktop conventions: Shift extends selections; Option-Arrow moves by word;
Command-Arrow and Home/End move to the line boundaries; Command-A/C/X/V select,
copy, cut, and paste; and word/line deletion chords work with the same
modifiers. Double-click selects a word, triple-click selects the whole line,
and dragging extends the corresponding selection. Checkboxes toggle completion
and Delete buttons remove tasks. Tab and Shift-Tab move focus through the field
and task controls in layout order, with wrapping; clicking also moves focus.
Focus remains explicit application state, and focused checkboxes and buttons
activate with Space or Enter. Submitting clears the field but leaves it focused
for the next task; Escape clears focus, while Cmd-Q and the window close button
still quit. The demo is deliberately in-memory; restarting it begins with an
empty list.

The checked-in [`roc-ray-platform`](roc-ray-platform) directory is a narrow Roc
facade over that host. It exposes only window state, keyboard/mouse input, text
measurement, and the drawing primitives needed by Puri. The upstream package
currently exposes several unrelated game modules that do not typecheck with
this repository's pinned compiler; keeping a small facade also avoids making
Puri depend on RocRay's asset and game APIs.

The todo milestone reuses the unmodified upstream RocRay host binary. A tiny
local hosted C adapter disables Raylib's default Escape-to-close key after
window initialization, exposes Raylib's system text clipboard and nested
scissor rectangles, and counts nearby clicks for the pointer events Puri
consumes. The fallback click counter uses a 500 ms interval and four-pixel slop
rather than the operating system's configured double-click values. Escape
handling does not affect Cmd-Q or the window close button. On macOS, Magnet's
"Snap windows by dragging" feature can make Raylib miss short clicks; quit
Magnet or disable that feature while running the demo. See
[raylib issue #4749](https://github.com/raysan5/raylib/issues/4749).

The demo does not require a RocRay fork or rebuilt host, or persistence.

RocRay currently exposes key states but not Raylib's entered-codepoint queue,
so the demo converts US letter, digit, space, and punctuation key positions to
ASCII text. Puri's text editing core is UTF-8 safe; keyboard-layout-aware text,
full Unicode entry, and IME require extending the platform input snapshot.
RocRay does not expose scissoring in its Roc package, so the local adapter calls
Raylib's scissor API directly. `PuriCanvasRocRay.with_clip!` intersects nested
scopes and the line editor horizontally scrolls its drawing to keep the focused
caret inside the field.

## Beyond the todo milestone

A per-frame UTF-8/codepoint input queue, persistence, and IME window integration
are intentionally deferred until an application needs them. Those can be small
upstreamable RocRay/platform additions instead of prerequisites for this
example. The same seams can later grow scroll panels, richer vector primitives,
and a browser Canvas interpreter without changing Puri's widget or handler
encodings.
