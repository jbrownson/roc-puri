# Puri–Roclay integration

This optional package adapts layout-independent Puri widgets to the sibling
Roclay project.

- [`PuriRoclay.roc`](PuriRoclay.roc) lifts measured widgets into leaves and
  placement widgets into decorators.
- [`PuriFrame.roc`](PuriFrame.roc) adds layout-aware padding, background, and
  border chrome.
- [`PuriRoclayScrollView.roc`](PuriRoclayScrollView.roc) supplies Roclay's
  controlled-container geometry and placement continuation to core Puri's
  scroll-view behavior.

Its manifest uses relative references to the Puri, Roclay, and geometry
packages. Those are the only paths that would need to become package URLs if
the projects are published separately.
