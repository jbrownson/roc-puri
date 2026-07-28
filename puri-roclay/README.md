# Puri–Roclay integration

This optional package adapts layout-independent Puri widgets to the sibling
Roclay project.

- [`Layout.roc`](Layout.roc) turns explicit preferred/minimum sizes plus a
  placement widget into a Roclay leaf, and can attach a placement widget to
  Roclay's exit phase.
- [`Widgets.roc`](Widgets.roc) combines Puri's separate widget sizing helpers
  and placement widgets for the standard controls.
- [`Frame.roc`](Frame.roc) adds independent background/border decoration or
  conventional framed padding.
- [`ScrollView.roc`](ScrollView.roc) supplies Roclay's
  controlled-container geometry and placement continuation to core Puri's
  scroll-view behavior.
- [`ReorderableList.roc`](ReorderableList.roc) composes Puri's stateless drag
  routing and transient reorder state with Roclay. Applications supply an
  arbitrary row renderer which receives its interactive handle; the
  combinator supplies exact handle hits, row-sized gaps, midpoint targeting,
  and a floating top-layer row.

Reordering uses a two-phase start to keep geometry explicit. Pointer-down on
the nested handle arms its item index. The first movement is then observed at
the containing row, where Roclay has settled the complete row rectangle. This
avoids requiring a retained identity, geometry cache, or guessed handle width.
The application list is changed only by the supplied drop callback.

`EditableText` owns its internal content padding because that padding affects
both drawing and the control's hit area. This integration treats it as an
ordinary Roclay leaf. Applications can independently decorate that leaf with
`Frame.decorate!` without teaching Roclay anything specific about line edits.

Its manifest uses relative references to the Puri, Roclay, and geometry
packages. Those are the only paths that would need to become package URLs if
the projects are published separately.

## Tests

The tests exercise the integration boundary with a recording canvas and a
small native test platform. Reorderable-list tests verify that only the
supplied handle arms a row, activation captures its complete settled
placement, movement changes only the preview gap, and release commits:

```sh
make check
make test
make docs
```
