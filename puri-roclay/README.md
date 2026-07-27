# Puri–Roclay integration

This optional package adapts layout-independent Puri widgets to the sibling
Roclay project.

- [`Layout.roc`](Layout.roc) turns explicit preferred/minimum sizes plus a
  placement widget into a Roclay leaf, and lifts placement widgets into
  decorators.
- [`Widgets.roc`](Widgets.roc) combines Puri's separate widget sizing helpers
  and placement widgets for the standard controls.
- [`Frame.roc`](Frame.roc) adds layout-aware padding, background, and
  border chrome.
- [`ScrollView.roc`](ScrollView.roc) supplies Roclay's
  controlled-container geometry and placement continuation to core Puri's
  scroll-view behavior.

Its manifest uses relative references to the Puri, Roclay, and geometry
packages. Those are the only paths that would need to become package URLs if
the projects are published separately.

## Tests

The tests exercise the integration boundary with a recording canvas and a
small native test platform:

```sh
make check
make test
make docs
```
