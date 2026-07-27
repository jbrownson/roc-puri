# Puri

Puri (pronounced “pure-eye”) is a renderer- and layout-independent immediate UI
library for Roc. A widget description is ephemeral data needed for the current
frame, not a retained widget object or a prescribed application-model shape.
Focus, text, selection, and other durable state remain explicit application
data.

## Core model

[`PuriCanvas`](PuriCanvas.roc) is a record of direct rendering operations.
Each operation may perform platform effects and returns a generic composable
result. [`PuriHandler`](PuriHandler.roc) contains transient event channels and
focus traversal information. [`Puri`](Puri.roc) combines both into:

```roc
Frame(result, context)
Widget(result, context) : Placement => Frame(result, context)
```

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

- [`PuriHandler`](PuriHandler.roc), [`PuriCanvas`](PuriCanvas.roc), and
  [`Puri`](Puri.roc) define the composition model.
- [`PuriButton`](PuriButton.roc), [`PuriCheckbox`](PuriCheckbox.roc), and
  [`PuriTextButton`](PuriTextButton.roc) provide standard controls while
  leaving appearance caller-supplied.
- [`PuriLineEdit`](PuriLineEdit.roc) is the pure UTF-8-safe editing state
  machine; [`PuriLineEditWidget`](PuriLineEditWidget.roc) adds drawing and
  events. Clipboard functions are supplied by the application.
- [`PuriScrollView`](PuriScrollView.roc) implements clipping, scrolling,
  bounded child handlers, and focus revelation over layout-supplied viewport,
  content-size, and placement continuations.
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
