# Geometry2d

`Geometry2d` is the small, renderer-independent geometry package shared by
Puri and Roclay.

It provides generic `Point`, `Size`, `Rect`, `Insets`, and `Placement` values.
A placement contains both the final layout rectangle and its effective
`clip_rect`: the intersection of that rectangle with every active enclosing
clip. The latter is therefore the visible, hit-testable subset of the
placement. It lets widgets reject events outside an enclosing viewport and
skip fully hidden rendering without making geometry responsible for activating
renderer clipping.

The package has no dependencies:

```roc
package [Geometry2d] {}
```

## Files

- [`main.roc`](main.roc) is the package manifest.
- [`Geometry2d.roc`](Geometry2d.roc) contains the public API and inline tests.

## Commands

```sh
make check
make test
make docs
```
