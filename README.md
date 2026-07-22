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
  compatibility.
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
  channels; [`PuriCanvas`](src/PuriCanvas.roc) is the direct-call rendering
  dictionary; and [`Puri`](src/Puri.roc) threads both through placement.
- [`PuriLineEdit`](src/PuriLineEdit.roc) provides pure UTF-8 editing
  transitions over independently supplied text and selection values.
  [`PuriLineEditWidget`](src/PuriLineEditWidget.roc) consumes an ephemeral
  per-frame description, renders it, then registers pointer/key handlers
  against the settled Roclay placement.
- [`PuriCanvasRecording`](src/PuriCanvasRecording.roc) is the initial
  interpreter used by tests. Production canvases do not build commands.
- [`PuriCanvasRocRay`](src/PuriCanvasRocRay.roc) is a direct native interpreter
  over RocRay/Raylib, and [`PuriRocRayDemo`](src/PuriRocRayDemo.roc) is an
  interactive todo/text-box vertical slice on the new Roc compiler.

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
make fuzz-flat
make fuzz-tree
make fuzz-text
make oracle
make native-headless
make native-run
```

The fuzz targets are deterministic and save their replayable input under
`build/`. Their case counts and seeds can be overridden, for example:

```sh
make fuzz-text TEXT_FUZZ_CASES=1000 TEXT_FUZZ_SEED=1
make fuzz-tree TREE_FUZZ_CASES=250 TREE_FUZZ_SEED=2
```

`make conformance` currently supports native Apple Silicon and Intel macOS. It
builds a deliberately tiny C platform in [`test-platform`](test-platform) so
the effectful continuation tests do not depend on basic-cli or RocRay.

## Native RocRay demo

`make native-run` downloads the pinned RocRay 0.8 platform bundle, reuses its
prebuilt Zig/Raylib 6 host, builds `PuriRocRayDemo`, and opens a resizable native
window. `make native-headless` builds the same executable and exercises three
frames through RocRay's headless host mode, which is suitable for CI.

The checked-in [`roc-ray-platform`](roc-ray-platform) directory is a narrow Roc
facade over that host. It exposes only window state, keyboard/mouse input, text
measurement, and the drawing primitives needed by Puri. The upstream package
currently exposes several unrelated game modules that do not typecheck with
this repository's pinned compiler; keeping a small facade also avoids making
Puri depend on RocRay's asset and game APIs.

RocRay currently exposes key states but not Raylib's entered-codepoint queue,
so the demo converts letter/digit keys to ASCII text. Puri's text editing core
is UTF-8 safe; full Unicode entry and IME require extending the platform input
snapshot. RocRay also does not yet expose scissoring, so the adapter's scoped
clip continuation preserves call ordering but does not clip pixels yet.

## Next

The next native slice is an upstreamable RocRay extension for scissoring and a
per-frame UTF-8/codepoint input queue. That unlocks real scroll panels and text
entry beyond the demo's ASCII adapter. After that, the same seams can grow IME
preedit, richer vector primitives, and a browser Canvas interpreter without
changing Puri's widget or handler encodings.
