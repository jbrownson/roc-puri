# RocRay mouse-edge host patch

These host archives are RocRay 0.8.0 rebuilt from tag `0.8.0` with
`0001-queue-mouse-button-edges.patch` and Zig 0.16.0 in `ReleaseFast` mode.
The unmodified RocRay 0.8.0 Raylib archive is still downloaded and linked by
the normal `make native-deps` path.

Raylib normally reduces mouse input to the button state at the end of each
frame. A press and release received in one GLFW poll therefore look like
up-to-up and both edges are lost. The patch chains Raylib's GLFW mouse callback,
queues the raw edges, and publishes at most one edge in each Roc host snapshot.
This also ensures that Puri reconstructs its transient handler between a press
and its release.

The source patch is included both for review and to make the binary provenance
reproducible. To rebuild it, check out
`https://github.com/lukewilliamboswell/roc-ray` at tag `0.8.0`, then run from
that checkout:

```sh
git apply --unidiff-zero /path/to/0001-queue-mouse-button-edges.patch
zig build test -Droc-tests=false
zig build -Doptimize=ReleaseFast
```

Copy `platform/targets/{arm64mac,x64mac}/libhost.a` into the corresponding
directories here. RocRay is distributed under the Universal Permissive
License; see `LICENSE`.
