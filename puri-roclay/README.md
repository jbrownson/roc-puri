# Puri–Roclay integration

This optional package adapts layout-independent Puri widgets to the sibling
Roclay project.

- [`Layout.roc`](Layout.roc) turns explicit preferred/minimum sizes plus a
  placement widget into a Roclay leaf, and lifts placement widgets into
  decorators.
- [`Widgets.roc`](Widgets.roc) combines Puri's separate widget sizing helpers
  and placement widgets for the standard controls.
- [`Frame.roc`](Frame.roc) adds independent background/border decoration or
  conventional framed padding.
- [`ScrollView.roc`](ScrollView.roc) supplies Roclay's
  controlled-container geometry and placement continuation to core Puri's
  scroll-view behavior.

`EditableText` owns its internal content padding because that padding affects
both drawing and the control's hit area. This integration treats it as an
ordinary Roclay leaf. Applications can independently decorate that leaf with
`Frame.decorate!` without teaching Roclay anything specific about line edits.

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
