# Puri for Roc

Puri is an experiment in pure UI components that do
not commit the surrounding system to one state-management architecture.

UI frameworks must account for durable control state such as text selections,
focus, and scroll offsets. Retained-mode frameworks put it in a widget tree.
Immediate-mode frameworks appear to discard the UI each frame, but commonly
keep state in a hidden store and use stable IDs—derived from explicit keys,
hashes, or call order—to reconnect new calls to old state. React-style systems
reconcile descriptions with retained component state. Each approach usually
bakes its answer into the component API.

Puri sits below that choice. Its components retain no state and require no
identity; they consume the data needed for one placement and produce rendering
plus one-shot event handling. A layer above can source that data from an
explicit application model, retained objects, an ID-keyed immediate store, a
React-like reconciler, or another scheme. UI libraries often make layout and
rendering pluggable; Puri extends that modularity to state management itself.

This is deliberately a low-level boundary, not an attempt to make the smallest
UI take the fewest lines of code. Its aim is to expose the real state and
composition problem so that complex UIs acquire no more complexity than they
need. Higher-level retained, immediate, or React-style APIs can recover
convenience while sharing Puri's widget behavior and backend integrations.

The absence of required identity also shaped Roclay. Clay normally returns a
render-command array whose entries carry IDs and user data. Roclay instead
attaches a continuation to each layout leaf and invokes it when that leaf's
final placement is known. Rendering and handler construction therefore remain
directly associated with the code that requested the layout; Puri never has to
tag layout outputs and reconnect them to widgets afterward.

[`MOTIVATION.md`](MOTIVATION.md) develops this argument, from the immediately
useful one-state-model approach through the longer-term motivation of
incremental UI.

This source workspace contains Puri, a continuation-based port of Clay's layout
behavior named Roclay, their supporting packages, a narrow native platform
facade, and a complete Todo example.

## Status

This is an experimental design prototype, not a released Roc package. Its APIs
are expected to change as the design is discussed and tested.

I learned Roc while building this project and am still very new to the
language. Feedback and criticism are warmly encouraged, both on Puri's ideas
and on the Roc code, APIs, organization, and style. Please do not assume that
an unusual choice is intentional or idiomatic.

The implementation targets nightlies of the new Zig-based Roc compiler—not the
older alpha4 compiler—and is pinned to the same nightly used to build RocRay
0.9's host:

```text
Roc compiler version nightly-2026-August-05-24f0b47
```

The native example and executable test hosts currently support macOS on Apple
Silicon and Intel. The Puri, Geometry, and Roclay source is not inherently
macOS-specific.

[`ROC_NOTES.md`](ROC_NOTES.md) records compiler limitations, platform friction,
and language-design questions encountered while developing the workspace.

## Projects

- [`geometry`](geometry) — generic 2D geometry shared by the libraries.
- [`roclay`](roclay) — a continuation-based port of Clay 0.14's layout
  behavior. Nic Barker's
  [algorithm video](https://youtu.be/by9lQvpvMIc) provides a visual
  introduction to Clay's approach.
- [`puri`](puri) — pure UI components independent of state management,
  renderer, and layout engine.
- [`puri-roclay`](puri-roclay) — the optional integration package connecting
  Puri widgets to Roclay layouts, including a reusable reorderable-list
  combinator.
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

## One frame in Puri

The Todo loop shows the complete lifecycle:

```roc
events = RocRayInput.events!(host)
next_model = EventLoop.run!(events, host.timestamp_nanos, model, build_frame!)
```

Each builder describes an ephemeral Roclay layout from the current application
model. `Roclay.place!` solves that layout and invokes each widget with settled
geometry, combining placement results and event handlers into one `Frame`.
`EventLoop` offers exactly one event to that one-shot handler, discards the
frame, then rebuilds from the resulting model before offering another event.
Intermediate frames use a silent Canvas that executes the complete layout and
placement pass without drawing; the final frame draws directly through RocRay.
An empty input batch becomes one timestamped `TimePassed` event. The common
zero- or one-input cases still perform exactly one layout.

This explicit application model is Todo's chosen state-management layer, not a
requirement imposed by Puri. Nothing in Puri retains a widget tree, owns that
model, or needs an identity with which to recover state from an earlier frame.
Roclay is an optional way to obtain placements, and RocRay is one Canvas/input
backend.

The Todo label editor shows the practical value of exposing those boundaries.
The second click replaces a label with an editor, seeds the editor's selection
at the corresponding text position, and composes a small pointer-move
hysteresis handler so that the layout change itself does not begin a selection
drag. The remainder of that multi-click run is translated into the editor's
frame of reference, so the third physical click is its logical double click
rather than an inherited triple click. Holding and moving the transition click
becomes an ordinary text selection drag. This behavior can be tuned directly
because the press, selection, handlers, and settled geometry are ordinary
explicit values.

Achieving the same behavior through a traditional retained widget API would
typically be extremely difficult: the old label's press state and the new
editor's selection and drag state live behind different widget identities.

## Why there is a local RocRay platform

The [`roc-ray-platform`](roc-ray-platform) project is an intentionally unusual
part of the demo. RocRay was the closest available native platform, but its Roc
API did not expose everything needed for ordinary Puri controls: clipboard
access, minimum window sizing, and control over Raylib's Escape-to-exit
behavior. Multi-click recognition is ordinary explicit application state in
Puri, not a platform effect.

Roc platforms cannot currently be extended like ordinary library APIs. Rather
than fork and rebuild RocRay's native host, this project:

1. downloads RocRay 0.9's unmodified precompiled `libhost.a` and
   `libraylib.a`;
2. declares a smaller replacement Roc platform surface compatible with that
   host ABI; and
3. links a local C adapter that exposes the missing Raylib functions from the
   existing archive.

The result is a small amount of narrowly isolated but undeniably awkward ABI
machinery. It lets the example demonstrate realistic text editing and scrolling
without making Puri depend on RocRay or maintaining a native host fork. A
different application can supply an entirely different Canvas and input
backend. The platform's [README](roc-ray-platform/README.md) explains which
pieces are upstream-derived and which are local; [`ROC_NOTES.md`](ROC_NOTES.md)
discusses the broader platform-composition problem.

### Runtime performance

An earlier version of this demo pinned RocRay 0.8, whose bundled host used
Zig's debug allocator. A [community profiling pass](https://roc.zulipchat.com/#narrow/channel/304641-ideas/topic/Thoughts.20on.20UI/near/614107747)
found that about 96% of Todo's frame time was spent capturing allocation stack
traces. Rebuilding with Zig's `smp_allocator` improved throughput by about 45×
and sustained 60 fps with 93 tasks. RocRay 0.9 adopted that allocator for
ordinary runs, so the pinned upstream host now includes the relevant fix.

Puri does allocate more per frame than an ID-based state-reconnection approach,
so this does not establish its eventual performance ceiling. It does establish
that the severe slowdown observed with 0.8 was dominated by its diagnostic
allocator, not layout or Puri's state model. If the experiment continues, a
purpose-built Linebender platform remains the preferred next native backend.

## Finally tagless, briefly

Puri follows a *finally tagless* style: a widget does not build a tree of
drawing commands for a later interpreter. It receives operations from its
caller and invokes them while it is being placed. The
[`Canvas`](puri/Canvas.roc) record is the small algebra used for drawing:

```roc
Canvas.Operations(result, paint) : {
    fill_rect! : Geometry.Rect, paint => result,
    fill_text! : Geometry.Point, paint, Str => result,
    # ...
}
```

“Tagless” contrasts this with defining tagged values such as `FillRect` and
`FillText`, collecting them into a command tree, and interpreting that tree
later. The program is represented by what it does with the supplied
operations, not by a syntax tree describing those operations.

A native implementation can draw immediately and return `{}`. A test
implementation can return recorded commands. Widgets remain independent of
either backend, and [`Frame`](puri/Frame.roc) combines that rendering result
with the event handler produced during the same placement.

Roclay uses the same idea from the other direction. Its layout nodes contain
continuations that receive their final `Placement`; invoking those
continuations runs the widgets instead of assigning identities to leaf values
in a retained output tree. A transparent `around` continuation derives entry
and exit behavior, preserving Clay's background–content–border ordering
without constructing render commands.

In Haskell, Puri can abstract over the rendering effect using higher-kinded
types and a monadic interface. Roc cannot express that abstraction directly,
so this version specializes the idea to first-order placement results that
compose through `default` and `plus`, plus ordinary effectful functions. The
tradeoff is discussed further in [ROC_NOTES.md](ROC_NOTES.md).

## Requirements

- the Roc nightly shown above, or a compatible newer Zig-compiler nightly
  installed using Roc's
  [official instructions](https://www.roc-lang.org/install/) and available as
  `roc` on `PATH`;
- macOS and the Xcode Command Line Tools for native builds;
- `make`, a C compiler, `curl`, and `tar`;
- Python 3 only for Roclay's generated conformance tests, fuzzing, and reducer.

The first native build performs the RocRay download described above. Its URL,
version, and extracted inputs are controlled by
[`roc-ray-platform/Makefile`](roc-ray-platform/Makefile); downloads and build
products remain ignored.

## Running the example

The root Makefile exists only for the integrated application and workspace
cleanup:

```sh
make run
# Equivalent: make native-run
make -C todo native-speed-run
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
   [`Frame`](puri/Frame.roc), followed by [`EventLoop`](puri/EventLoop.roc) for
   batching platform events without reusing a frame's handler.

3. A small standard component:
   [`Button`](puri/Button.roc), consulting [`Event`](puri/Event.roc) as its
   input types arise, then the small placement-level
   [`Interact`](puri/Interact.roc) combinators. [`KeyboardFocus`](puri/KeyboardFocus.roc)
   is an optional, non-rendering component that traverses an
   application-supplied order. [`Drag`](puri/Drag.roc) and
   [`Reorder`](puri/Reorder.roc) provide the layout-independent mechanics used
   by the Todo's draggable rows. The other standard components follow the same
   pattern.

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
   ordinary leaf—then [`Frame`](puri-roclay/Frame.roc) and the composed
   [`ReorderableList`](puri-roclay/ReorderableList.roc).

7. The application:
   [`Todo`](todo/Todo.roc), the application-specific focus order in
   [`TodoFocus`](todo/TodoFocus.roc),
   [`TodoUi`](todo/TodoUi.roc), and [`TodoTaskRow`](todo/TodoTaskRow.roc),
   followed by [`main`](todo/main.roc). Treat [`TodoTheme`](todo/TodoTheme.roc)
   and the RocRay adapters as backend-specific detail.

Each project README describes its own API and verification strategy in more
detail.

## Future work

- **Exercise state-management independence.** Build small retained,
  immediate-mode, and reconciler-style layers against the same Puri widgets.
  This would test the central claim more convincingly than documentation alone
  and reveal where widget interfaces still assume the Todo example's model.
- **Broaden the widget catalog.** Add compositional controls such as radio
  buttons, menus, sliders, tabs, dialogs, lists, and richer text editing while
  continuing to keep their state explicit. The existing single-line editor
  deliberately stops short of full Unicode grapheme handling, input methods,
  and rich text.
- **Add real backends.** A browser/Wasm platform using DOM events and Canvas,
  and a native platform using Linebender's rendering stack, are the most useful
  next targets. A purpose-built native platform would also remove the current
  dependence on RocRay's packaged host artifacts and make Linux and Windows
  support practical.
- **Develop an accessibility story.** Determine how explicit widget
  descriptions and application-managed focus can feed roles, labels, values,
  and actions to platform accessibility APIs without coupling Puri to a
  particular backend.
- **Avoid unnecessary whole-frame work.** Explore caching, partial
  invalidation, and incremental layout/rendering without hiding state or
  introducing output identity as a prerequisite. The delta model described in
  [MOTIVATION.md](MOTIVATION.md) is one possible research direction, not a
  requirement for using Puri.
- **Harden and package the boundaries.** Expand backend-independent widget
  tests, test Roclay's public API beyond Clay conformance, refine naming with
  Roc community feedback, and eventually publish the component directories as
  independent packages.

## Development provenance

Puri's design predates this Roc implementation, which ports earlier Haskell
and Rust implementations developed as part of
[Progred](https://github.com/jbrownson/progred). Those versions explore the
same state-explicit component model using Haskell's higher-kinded abstractions
and Rust's traits. That repository is ongoing research context, not yet a
standalone or documented Puri distribution, and the larger Progred project
needs more explanation than this README attempts to provide. Interested
readers are welcome to ask about that context.

Jake Brownson originated and directed the design. He carefully hand-reviewed
and iteratively revised Puri's core abstractions—particularly Geometry,
Handler, Canvas, Frame, Button, the state/focus boundaries, and the package
organization. That work included module-by-module discussion of types,
composition, naming, and factoring, often followed by further implementation
changes. Those parts should be understood as collaboratively authored, not as
generated code accepted without review.

Most code was initially written through iterative collaboration with OpenAI
Codex (GPT-5.6). Puri's core abstractions received the close review described
above. The portions that did not are supporting implementations rather than
the core idea: Roclay's solver and conformance machinery, the text editor's
internal algorithms, and many secondary widgets, adapters, tests, and platform
details.

### Roclay

Roclay's public purpose and testing strategy were discussed, but its solver
internals and most of its conformance infrastructure were barely hand-reviewed.
The Clay oracle and fuzzing harness were designed specifically to build
behavioral confidence despite that lack of source review. A standalone C
process embeds an unmodified Clay 0.14 header; Roclay does not link to it. Each
generated case is sent to Clay, then emitted as an equivalent Roc program whose
placement continuations record Roclay's output. The harness compares the
number, order, and coordinates of element or text-line rectangles, accepting
differences below `0.05` display units.

Three deterministic generators cover different parts of the model. Flat cases
vary row/column direction, padding, gaps, alignment, fit/fixed/fill/percent
sizing with min/max constraints, aspect ratios, and one to four children.
Recursive cases combine nested containers with intrinsic and text leaves,
clipping flags, child offsets, sizing constraints, aspect ratios, and text
wrapping. Text cases independently vary available size, word/newline/no-wrap
modes, alignment, font size, line height, and generated line contents. The
normal fuzz targets generate 250 flat cases, 50 substantially larger recursive
trees, and 250 text cases from recorded seeds. Counts and seeds are
configurable; larger transient runs were also used during development.

Generated Roc programs and wire corpora make failures replayable. The tree
reducer reconstructs a failure from its seed and case number, then greedily
removes children and simplifies properties while repeatedly asking whether the
Clay/Roclay mismatch remains. Because generated corpora are ignored build
products, the repository does not preserve an auditable cumulative count for
the larger development runs. This is broad differential testing over the
generated domains, not a proof that Roclay matches every Clay behavior.

### Other less-reviewed areas

- The text editor's public decomposition and behavior were reviewed, while its
  editing algorithms, UTF-8 helpers, caret measurement, and much of
  `EditableText` were not reviewed line by line.
- The Todo was exercised extensively as an application, but many secondary
  widgets, adapters, tests, and platform details were not carefully audited as
  source.

The less-reviewed areas identified above are effectively vibe-coded.
Confidence in them comes from executable tests, hands-on use of the Todo, and
the Roclay differential testing described above. That validation is useful,
but it should not be mistaken for careful human review of the implementation.

## License

Original work in this repository is available under the
[Universal Permissive License, Version 1.0](LICENSE). See
[`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md) for Clay, RocRay, and
raylib attribution and license notices.
