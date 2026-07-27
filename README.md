# Puri for Roc

This repository is an in-progress Roc port of Puri and its
continuation-based layout companion, Halay. The first milestone is Roclay: a
small layout library whose geometry matches Clay 0.14, but whose public API
exposes measurement and placement continuations instead of render commands.

The implementation targets recent nightlies of the new Zig-based Roc compiler
and was last verified with the 2026-07-25 nightly,
`release-fast-b6cdced9`.

## Repository layout

- [`geometry`](geometry) is a standalone package exposing the generic
  [`Geometry2d`](geometry/Geometry2d.roc) module shared by the libraries.
- [`roclay`](roclay) is a standalone package exposing `Roclay` through
  [`roclay/main.roc`](roclay/main.roc) and depending only on geometry. The
  compact [`Roclay`](roclay/Roclay.roc) type module is its public API;
  [`RoclayInternal`](roclay/RoclayInternal.roc) contains the package-private
  constraint solver.
- [`puri`](puri) is a standalone Roc package exposing the reusable UI modules
  through [`puri/main.roc`](puri/main.roc). It depends only on geometry and
  exposes placement-level widgets rather than choosing a layout engine.
- [`puri-roclay`](puri-roclay) is the optional integration package. It depends
  on Puri and Roclay, lifts Puri widgets into Roclay leaves and decorators, and
  owns components whose behavior inherently changes layout.
- [`examples/todo`](examples/todo) contains the application, its independent
  [`Todo`](examples/todo/Todo.roc) model, its
  [`TodoUi`](examples/todo/TodoUi.roc) page composition,
  [`TodoTaskRow`](examples/todo/TodoTaskRow.roc) application-specific row, and
  [`TodoTheme`](examples/todo/TodoTheme.roc) RocRay style binding. The two
  RocRay-specific adapters and platform lifecycle remain separate, with the
  lifecycle in a short
  [`main.roc`](examples/todo/main.roc).
- [`tests`](tests) mirrors the package boundary. The Roclay oracle adapters and
  [`Clay reference implementation`](tests/roclay/oracle) are test-only; Puri's
  recording canvas is test support rather than public API; and effectful tests
  use the minimal [`test-platform`](test-platform).
- [`roc-ray-platform`](roc-ray-platform) and
  [`compiler-repro`](compiler-repro) contain platform integration and isolated
  compiler investigations respectively.

The reusable dependency graph is intentionally one-way:

```text
puri        -> geometry
roclay      -> geometry
puri-roclay -> puri + roclay
```

Each `.roc` file remains one module. The `package [...] { ... }` header in a
`main.roc` chooses which sibling modules consumers may import and declares
dependencies. For example, the todo app imports `puri.PuriButton` and
`roclay.Roclay`; directory nesting by itself would not create those namespaces.

## Current slice

- [`Geometry2d`](geometry/Geometry2d.roc) provides renderer-independent geometry.
  Its `Point`, `Size`, `Rect`, `Insets`, and `Placement` types are generic in
  the scalar; Roclay specializes them to `F32` for Clay and graphics-API
  compatibility. A placement carries both the full settled layout rectangle
  and its effective `clip_rect`, inherited through enclosing layouts. Widgets
  use that visible rectangle for hit-testing and may use it for render culling;
  actual renderer clipping remains an explicit canvas operation.
- [`Roclay`](roclay/Roclay.roc) exposes rows, columns, padding, gaps, fit,
  fixed, fill, percent, min/max constraints, alignment, aspect ratio, clips,
  child offsets, intrinsic leaves, width-sensitive text, decorators, and
  controlled containers. [`RoclayInternal`](roclay/RoclayInternal.roc)
  implements the layout passes behind that API.
- [`RoclayPlacementTests`](tests/roclay/RoclayPlacementTests.roc) checks fixed
  Clay placements, continuation-driven controlled containers, and effective
  clip propagation.
- [`clay_oracle.c`](tests/roclay/oracle/clay_oracle.c) and the vendored Clay
  0.14 header are the independent behavioral oracle. See the
  [`oracle README`](tests/roclay/oracle/README.md).
- Deterministic generators cover flat containers, recursive trees, and text.
  Recursive trees mix intrinsic and text leaves, so wrapping is exercised
  under nested sizing, clipping, offsets, and aspect ratios.
- [`PuriHandler`](puri/PuriHandler.roc) provides transient, composed event
  channels and a compositional per-frame focus traversal summary;
  [`PuriCanvas`](puri/PuriCanvas.roc) is the direct-call rendering dictionary;
  and [`Puri`](puri/Puri.roc) combines rendering results and handlers into a
  per-placement frame.
- [`PuriLineEdit`](puri/PuriLineEdit.roc) exposes pure UTF-8 editing transitions
  over independently supplied text and selection values, including
  character/word motion and deletion, selection extension, multi-click
  selection, and clipboard commands. Byte scanning and word classification are
  package-private in
  [`PuriLineEditInternal`](puri/PuriLineEditInternal.roc).
  [`PuriLineEditWidget`](puri/PuriLineEditWidget.roc) consumes an ephemeral
  per-frame description and produces a measured placement callback that draws
  and registers pointer/key handlers against whatever final placement a layout
  engine supplies.
- [`PuriButton`](puri/PuriButton.roc) ports Puri's generic button interaction:
  drawing is caller-supplied, focus is explicit, and pointer, Enter, and Space
  activation all dispatch directly into application transitions.
  [`PuriCheckbox`](puri/PuriCheckbox.roc) is a styled specialization built on
  that generic button rather than a stateful control implementation.
- [`PuriTextMeasurement`](puri/PuriTextMeasurement.roc) defines the shared,
  renderer-independent metrics and measurement capability.
  [`PuriText`](puri/PuriText.roc) turns supplied metrics into a directly
  rendered measured widget. [`PuriTextButton`](puri/PuriTextButton.roc)
  combines it with `PuriButton`, keeping the standard control in Puri while
  leaving font, color, and spacing choices with the application.
- [`PuriRoclay`](puri-roclay/PuriRoclay.roc) contains the two small adapters
  from a measured Puri widget to a Roclay leaf and from a Puri placement widget
  to a Roclay decorator.
- [`PuriFrame`](puri-roclay/PuriFrame.roc) provides Roclay-specific visual
  chrome: padding plus an optional background and inset border.
  [`PuriScrollView`](puri-roclay/PuriScrollView.roc) combines a Roclay
  controlled container with scoped rendering, bounded pointer handlers, wheel
  scrolling, and focus revelation. Its offset remains ordinary application
  state.
- [`PuriCanvasRecording`](tests/puri/support/PuriCanvasRecording.roc) is the
  test-only initial interpreter. Production canvases do not build commands.
- [`PuriCanvasRocRay`](examples/todo/PuriCanvasRocRay.roc) is a direct native
  interpreter over RocRay/Raylib;
  [`PuriInputRocRay`](examples/todo/PuriInputRocRay.roc) translates the host's
  frame snapshot into Puri events. [`TodoUi`](examples/todo/TodoUi.roc)
  assembles the page from named entry-row and task-list components;
  [`TodoTaskRow`](examples/todo/TodoTaskRow.roc) holds the todo-specific
  edit/toggle/delete policy; and [`TodoTheme`](examples/todo/TodoTheme.roc)
  binds standard Puri widgets to the demo's RocRay fonts and colors.
  [`main.roc`](examples/todo/main.roc) owns only initialization and the
  per-frame platform loop. Tasks can be added, toggled, edited, deleted, and
  scrolled; [`Todo`](examples/todo/Todo.roc) keeps those pure model transitions
  separate from ephemeral widget descriptions.

## Suggested reading order

1. Glance at the four package manifests, then start with
   [`Geometry2d`](geometry/Geometry2d.roc).
2. Read [`PuriHandler`](puri/PuriHandler.roc), [`PuriCanvas`](puri/PuriCanvas.roc),
   and [`Puri`](puri/Puri.roc) to see the event and rendering dictionaries plus
   the composable per-frame value that replace Haskell typeclasses or Rust
   traits.
3. Read [`PuriTextMeasurement`](puri/PuriTextMeasurement.roc),
   [`PuriText`](puri/PuriText.roc), and
   [`PuriButton`](puri/PuriButton.roc), then see them composed into
   [`PuriTextButton`](puri/PuriTextButton.roc). Follow with
   [`PuriCheckbox`](puri/PuriCheckbox.roc) for another styled specialization of
   the same generic button behavior.
4. Read the [`PuriLineEdit`](puri/PuriLineEdit.roc) public transitions, then
   [`PuriLineEditInternal`](puri/PuriLineEditInternal.roc) for the pure state
   machine and [`PuriLineEditWidget`](puri/PuriLineEditWidget.roc) for its
   drawing/event adapter.
5. Read the public [`Roclay`](roclay/Roclay.roc) facade, then follow `measure`
   into [`RoclayInternal`](roclay/RoclayInternal.roc). Its section headings
   separate measurement, constraint resolution, text layout, and placement.
   The tiny [`PuriRoclay`](puri-roclay/PuriRoclay.roc) module then shows the
   entire generic bridge, followed by its layout-specific
   [`PuriFrame`](puri-roclay/PuriFrame.roc) and
   [`PuriScrollView`](puri-roclay/PuriScrollView.roc) components. Finish with
   [`Todo`](examples/todo/Todo.roc),
   [`TodoTheme`](examples/todo/TodoTheme.roc),
   [`TodoTaskRow`](examples/todo/TodoTaskRow.roc), and the deliberately compact
   [`TodoUi`](examples/todo/TodoUi.roc), then read the short todo
   [`main.roc`](examples/todo/main.roc) and two RocRay adapters. The files under
   [`tests`](tests) are short executable examples of each API.

Roclay necessarily owns a constraint tree because parent and child sizes must
be solved together. Rendering remains finally tagless: after measurement,
leaf and decorator callbacks receive final placements and act immediately.
Each callback returns generic composable output:

```roc
Place(output) : Placement => output
PlaceKids(output) : Point => output
PlaceContainer(output) : Placement, ContainerInfo, PlaceKids(output) => output
MeasureText : Str => Size
PlaceTextLine(output) : U64, Str, Placement => output
```

`Roclay.measure` requires the output's standard `default` and `plus` methods;
placement folds output directly in callback and child order. Puri's output is
a `Frame`. The conformance interpreter's output is a nominal wrapper around a
list of recorded placements, giving us an initial encoding at the testing
boundary without imposing one on renderers.

`Roclay.text!` calls the supplied measurement function while constructing the
layout, wraps after horizontal sizes are resolved, and calls `place_line!`
with each final line. Text rendering is therefore direct too; Roclay does not
return a list of render commands.

Puri uses the same first-order dictionary pattern in place of Rust traits or
Haskell typeclasses. `PuriCanvas.Canvas(result, paint)` is a record of effect
functions such as `fill_rect!`, `fill_text!`, and scoped `with_clip!`. Each
operation may perform platform effects and returns one interpreter result. A
`Puri.Frame` pairs that result with the transient handler assembled during
placement. Both `Handler` and `Frame` are transparent nominal types implementing
Roc's conventional `default` and `plus` methods, so `+` composes them in
placement order. A frame's render result has the same structural requirement.
RocRay draws immediately and returns a trivial nominal result; the test
interpreter returns command fragments whose `plus` concatenates them.

Together, Roc's ambient `=>` effects and this monoidal result are the
first-order specialization of the Haskell API's higher-kinded `renderM`.
Concrete state or monadic computations can be defined in Roc, but Roc cannot
abstract over their type constructors with one `Monad` interface. This port
uses only the weaker structure its actual native and recording interpreters
need.

A widget argument is just the data required to describe this frame, not a
retained object or a prescribed application-model shape. An application can
store text and selection separately, derive either one, or construct an
entirely new line-edit value every frame. Puri has no global focused-control
or hidden text-box state.

Core widgets return `Puri.Widget` placement callbacks or
`Puri.MeasuredWidget` records containing preferred/minimum sizes and a callback.
They know only the shared geometry types. `PuriRoclay.leaf` and
`PuriRoclay.decorate` are the complete generic adapter surface; another layout
engine can consume the same sizes and invoke the same callbacks without
changing Puri.

## Build and test

[Install](https://www.roc-lang.org/install/) a recent new-compiler nightly and
make `roc` available on `PATH`, as in other active Roc projects. The version
above records the last compiler verified by this repository; it is not a
required local pin. Override `ROC=/path/to/roc` when comparing compiler builds
or reproducing an older bug.

```sh
make fmt-check
make check
make test
make docs
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

`make docs` writes the three reusable package APIs under `build/docs/`. In
particular, Roclay's generated docs omit the package-private solver passes.

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
`tests/roclay/RoclayTreeReduced*.roc` and `build/`; both are ignored so
reductions do not disturb the normal generated corpus.

`make conformance` currently supports native Apple Silicon and Intel macOS. It
builds a deliberately tiny C platform in [`test-platform`](test-platform) so
the effectful continuation tests do not depend on basic-cli or RocRay.

`make specialization-repro` preserves a small compiler-performance comparison
for Roclay's callback-parameterized output. See
[`compiler-repro/README.md`](compiler-repro/README.md) for measurements. It is
not part of the normal test or native-run targets.

## Native RocRay demo

`make native-run` downloads the pinned RocRay 0.8 platform bundle, reuses its
prebuilt Zig/Raylib 6 host, builds `PuriRocRayDemo` in Roc's development mode,
and opens a resizable native window. `make native-headless` builds the same
executable and exercises three frames through RocRay's headless host mode,
which is suitable for CI.

Make skips the native compiler when the executable is newer than all Roc
sources. When a rebuild is needed, the recipe disables Roc's internal compiler
cache and writes to a temporary output before atomically replacing the runnable
binary. This guards against stale or partial executables while the new compiler
is still under development.

An earlier pinned compiler's speed optimizer miscompiled this demo: after a
task was added, its row could be omitted or laid out past the window edge. The
underlying compiler bug was reported as
[roc-lang/roc#10317](https://github.com/roc-lang/roc/issues/10317) and fixed
upstream by [roc-lang/roc#10336](https://github.com/roc-lang/roc/pull/10336).
The last-tested nightly includes that fix.

The normal native targets continue to use `--opt=dev` because it rebuilds much
faster while the new compiler is under development. `make native-speed-run`
provides an explicit optimized build without replacing the development binary.

The bundled RocRay host itself was compiled in Zig's debug mode. Its allocator
and runtime checks can make scrolling feel uneven; the same per-frame overhead
is visible in an otherwise empty RocRay app. Rebuilding that host optimized is
possible, but is deliberately outside this self-contained demo milestone.

The draft field starts focused. Type a task and press Enter or choose Add. Text
editing follows desktop conventions: Shift extends selections; Option-Arrow moves by word;
Command-Arrow and Home/End move to the line boundaries; Command-A/C/X/V select,
copy, cut, and paste; and word/line deletion chords work with the same
modifiers. Double-click selects a word, triple-click selects the whole line,
and dragging extends the corresponding selection. Checkboxes toggle completion;
Edit replaces a task label with the same line editor, Done or Enter commits the
already-live changes, and Delete removes the task. Double-clicking a task applies
both constituent toggles (netting no completion change) and enters editing. The
task list clips and scrolls with a mouse wheel or high-resolution trackpad;
new tasks stay visible and keyboard traversal reveals offscreen controls. The
window has a 520-by-360 minimum size. Tab and Shift-Tab move focus through the
field and task controls in layout order, with wrapping; clicking also moves focus.
Focus remains explicit application state, and focused checkboxes and buttons
activate with Space or Enter. Submitting clears the field but leaves it focused
for the next task; Escape clears focus, while Cmd-Q and the window close button
still quit. The demo is deliberately in-memory; restarting it begins with an
empty list. Button and checkbox hover feedback is derived from the current
pointer position during placement, rather than retained in the application model.

The checked-in [`roc-ray-platform`](roc-ray-platform) directory is a narrow Roc
facade over that host. It exposes only window state, keyboard/mouse input, text
measurement, and the drawing primitives needed by Puri. The upstream package
currently exposes several unrelated game modules that do not typecheck with the
last-tested compiler; keeping a small facade also avoids making
Puri depend on RocRay's asset and game APIs.

The todo milestone reuses the unmodified upstream RocRay host binary. A tiny
local hosted C adapter disables Raylib's default Escape-to-close key after
window initialization, sets the minimum window size, exposes Raylib's system
text clipboard and nested scissor rectangles, preserves Raylib's fractional
two-axis scroll movement, and counts nearby clicks for Puri to consume. The
fallback click counter uses a 500 ms interval and four-pixel slop
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
Raylib's scissor API directly. Nested scopes are intersected by the adapter;
line editors horizontally scroll their drawing to keep the focused caret in the
field, and the Puri–Roclay `PuriScrollView` clips an offset child subtree
without changing Roclay's renderer-independent responsibilities.

## Beyond the todo milestone

A per-frame UTF-8/codepoint input queue, persistence, and IME window integration
are intentionally deferred until an application needs them. Those can be small
upstreamable RocRay/platform additions instead of prerequisites for this
example. The same seams can later grow richer vector primitives and a browser
Canvas interpreter without changing Puri's widget or handler encodings.
