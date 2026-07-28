# Puri

Puri is an experiment in UI components independent of
state-management architecture, renderer, and layout engine.

Retained, immediate, and React-style APIs differ largely in who owns durable
control state and how new UI descriptions reconnect to it. That choice is
usually built into their component model. Puri sits below the distinction: it
has no hidden widget store and no reconnection step. A Puri widget consumes an
ephemeral description, renders at a settled placement, and produces a one-shot
handler. It retains neither the description nor an identity between calls.

A caller can therefore drive the same widget from an explicit application
model, a retained object tree, an ID-keyed immediate store, a React-like
reconciler, or another state-management scheme. The included Todo chooses the
first option; Puri does not.

“Pure” here describes the component boundary, not an absence of rendering
effects. Placing a widget may draw directly through a Canvas. Puri itself
retains no temporal state; the surrounding layer decides where such state
lives and supplies the current description and generic handler state.

This Roc package ports earlier Puri implementations developed in Haskell and
Rust as part of [Progred](https://github.com/jbrownson/progred). Those sources
are ongoing research context rather than a standalone Puri distribution; the
workspace [provenance](../README.md#development-provenance) describes how this
Roc version was produced and reviewed.

The workspace-level [`MOTIVATION.md`](../MOTIVATION.md) expands on the
two-state synchronization problem, the simple one-state-model approach used by
Todo, and the longer-term incremental UI direction.

## Core model

[`Canvas`](Canvas.roc) defines a structural record of direct rendering operations.
This is Puri's finally-tagless rendering boundary: widgets call supplied
operations directly rather than constructing a tagged command tree for later
interpretation. Each operation may perform platform effects and returns a
generic composable result. [`Geometry`](Geometry.roc) selects the transparent
coordinate aliases used consistently across Puri. [`Event`](Event.roc) defines
portable pointer and key payload conventions. [`Handler`](Handler.roc) is a
nominal, composable event function. [`Frame`](Frame.roc) combines rendering and
event handling:

```roc
Frame(placement_result, state, event)
Widget(placement_result, state, event) :
    Placement => Frame(placement_result, state, event)
```

`Frame` knows nothing about layout negotiation. A `Widget` receives only
settled geometry—its full rectangle and the portion visible through active
enclosing clips—and produces a frame. The clip rectangle is geometry used for
hit-testing and culling; a Canvas operation such as `with_clip!` is what
actually activates renderer clipping. Standard widget modules expose sizing
calculations separately so an optional layout adapter can use them without
coupling placement to one layout protocol.

Widgets constrain `event` with open structural tag unions containing only the
cases they handle. Backends can combine those requirements and add unrelated
event tags without changing Puri or its widgets.

Puri has no global concept of focus. A widget may accept caller-supplied
focused state, change its appearance or handlers accordingly, and request a
state transition after a pointer event. Whether focus exists, how many focus
domains there are, and how keyboard traversal works remain policy of the
surrounding state-management layer. The optional `KeyboardFocus` widget draws
nothing and owns no state; it merely handles Tab over an explicit,
application-supplied order.

The top-level `Frame` and `Handler` types implement Roc's conventional `default` and `plus`
methods, so widgets compose in placement order. This is the first-order
specialization used in place of the Haskell API's higher-kinded `renderM`;
Roc can define particular monadic computations but cannot abstract over their
type constructors with one `Monad` interface.

`Frame.roc` and `Handler.roc` are type modules centered on their namesake
nominal types. The other files are void modules: their descriptions and
capability records remain structural, so an application or backend can supply
compatible values without wrapping them in Puri-owned types. The `Puri` prefix
is omitted because the package qualifier already supplies that namespace
(`puri.Handler`, `puri.Button`, and so on).

Puri depends only on [`geometry`](../geometry):

```roc
{
    geometry: "../geometry/main.roc",
}
```

It deliberately does not depend on a layout engine or native platform.

## Modules

- [`Geometry`](Geometry.roc), [`Event`](Event.roc), [`Handler`](Handler.roc),
  [`Canvas`](Canvas.roc), and [`Frame`](Frame.roc) define the input and
  composition model.
- [`EventLoop`](EventLoop.roc) rebuilds a fresh frame for every event in a
  platform batch while rendering only the final frame.
- [`Button`](Button.roc), [`Checkbox`](Checkbox.roc), and
  [`TextButton`](TextButton.roc) provide standard controls while
  leaving appearance caller-supplied.
- [`Interact`](Interact.roc) provides small event combinators over already
  settled placements, such as attaching an action to a double click.
- [`Drag`](Drag.roc) routes pointer drag phases through invisible,
  placement-aware widgets. [`Reorder`](Reorder.roc) supplies transient
  list-reordering state plus generic item and index movement; neither changes
  an application's list while a drag is merely being previewed.
- [`KeyboardFocus`](KeyboardFocus.roc) provides optional Tab traversal over an
  explicit order without discovering controls or retaining focus.
- [`LineEditing`](LineEditing.roc) is the pure UTF-8-safe editing engine;
  [`EditableText`](EditableText.roc) is the chrome-free text, selection, caret,
  content-padding, and event leaf. Clipboard functions are supplied by the
  application.
- [`ScrollView`](ScrollView.roc) implements clipping, scrolling, and
  bounded child handlers over layout-supplied viewport, content-size, and
  placement continuations. Its explicit position is either `AtOffset(n)` or
  geometry-dependent `AtEnd`.
- [`Text`](Text.roc) and
  [`TextMeasurement`](TextMeasurement.roc) provide measured text
  without selecting a font system.
- The peer [`puri-roclay`](../puri-roclay) package provides Roclay widget,
  scroll-view, and reorderable-list adapters plus layout-aware frame chrome.

## Tests

[`tests`](tests) owns a recording canvas, executable widget tests, and a small
native test platform. Core widgets are tested directly at explicit settled
placements, so Puri's source and tests remain independent of any layout engine.

```sh
make check
make test
make docs
make conformance
```
