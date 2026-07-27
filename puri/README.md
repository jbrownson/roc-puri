# Puri

Puri (pronounced “pure-eye”) is a renderer- and layout-independent immediate UI
library for Roc. A widget description is ephemeral data needed for the current
frame, not a retained widget object or a prescribed application-model shape.
Focus, text, selection, and other durable state remain explicit application
data.

## Core model

[`Canvas`](Canvas.roc) defines a structural record of direct rendering operations.
Each operation may perform platform effects and returns a generic composable
result. [`Event`](Event.roc) defines portable pointer and key payload
conventions. [`Handler`](Handler.roc) is a nominal, composable event function.
[`Frame`](Frame.roc) combines rendering and event handling:

```roc
Frame(placement_result, state, event)
Widget(placement_result, state, event) :
    Placement => Frame(placement_result, state, event)
```

`Frame` knows nothing about layout negotiation. A `Widget` receives only
settled geometry—its rectangle and current clip rectangle—and produces a
frame. Standard widget modules expose sizing calculations separately so an
optional layout adapter can use them without coupling placement to one layout
protocol.

Widgets constrain `event` with open structural tag unions containing only the
cases they handle. Backends can combine those requirements and add unrelated
event tags without changing Puri or its widgets.

Puri has no global concept of focus. A widget may accept application-supplied
focused state, change its appearance or handlers accordingly, and request an
application transition after a pointer event. Whether focus exists, how many
focus domains there are, and how keyboard traversal works remain application
policy.

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

- [`Event`](Event.roc), [`Handler`](Handler.roc),
  [`Canvas`](Canvas.roc), and [`Frame`](Frame.roc) define the input and
  composition model.
- [`Button`](Button.roc), [`Checkbox`](Checkbox.roc), and
  [`TextButton`](TextButton.roc) provide standard controls while
  leaving appearance caller-supplied.
- [`LineEdit`](LineEdit.roc) is the pure UTF-8-safe editing state
  machine; [`LineEditWidget`](LineEditWidget.roc) adds drawing and
  events. Clipboard functions are supplied by the application.
- [`ScrollView`](ScrollView.roc) implements clipping, scrolling, and
  bounded child handlers over layout-supplied viewport, content-size, and
  placement continuations.
- [`Text`](Text.roc) and
  [`TextMeasurement`](TextMeasurement.roc) provide measured text
  without selecting a font system.
- The peer [`puri-roclay`](../puri-roclay) package provides Roclay widget and
  scroll-view adapters plus layout-aware frame chrome.

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
