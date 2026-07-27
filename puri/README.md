# Puri

Puri (pronounced “pure-eye”) is a renderer- and layout-independent immediate UI
library for Roc. A widget description is ephemeral data needed for the current
frame, not a retained widget object or a prescribed application-model shape.
Focus, text, selection, and other durable state remain explicit application
data.

## Core model

[`PuriCanvas`](PuriCanvas.roc) is a record of direct rendering operations.
Each operation may perform platform effects and returns a generic composable
result. [`PuriEvent`](PuriEvent.roc) defines portable pointer and key payload
conventions. [`PuriHandler`](PuriHandler.roc) composes generic event functions.
[`Puri`](Puri.roc) combines rendering and event handling into:

```roc
Frame(result, state, event)
Widget(result, state, event) : Placement => Frame(result, state, event)
```

Widgets constrain `event` with open structural tag unions containing only the
cases they handle. Backends can combine those requirements and add unrelated
event tags without changing Puri or its widgets.

Puri has no global concept of focus. A widget may accept application-supplied
focused state, change its appearance or handlers accordingly, and request an
application transition after a pointer event. Whether focus exists, how many
focus domains there are, and how keyboard traversal works remain application
policy.

`Frame` and `Handler` implement Roc's conventional `default` and `plus`
methods, so widgets compose in placement order. This is the first-order
specialization used in place of the Haskell API's higher-kinded `renderM`;
Roc can define particular monadic computations but cannot abstract over their
type constructors with one `Monad` interface.

Puri depends only on [`geometry`](../geometry):

```roc
{
    geometry: "../geometry/main.roc",
}
```

It deliberately does not depend on a layout engine or native platform.

## Modules

- [`PuriEvent`](PuriEvent.roc), [`PuriHandler`](PuriHandler.roc),
  [`PuriCanvas`](PuriCanvas.roc), and [`Puri`](Puri.roc) define the input and
  composition model.
- [`PuriButton`](PuriButton.roc), [`PuriCheckbox`](PuriCheckbox.roc), and
  [`PuriTextButton`](PuriTextButton.roc) provide standard controls while
  leaving appearance caller-supplied.
- [`PuriLineEdit`](PuriLineEdit.roc) is the pure UTF-8-safe editing state
  machine; [`PuriLineEditWidget`](PuriLineEditWidget.roc) adds drawing and
  events. Clipboard functions are supplied by the application.
- [`PuriScrollView`](PuriScrollView.roc) implements clipping, scrolling, and
  bounded child handlers over layout-supplied viewport, content-size, and
  placement continuations.
- [`PuriText`](PuriText.roc) and
  [`PuriTextMeasurement`](PuriTextMeasurement.roc) provide measured text
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
