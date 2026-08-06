# Narrow RocRay platform facade

This project describes the subset of
[RocRay 0.9](https://github.com/lukewilliamboswell/roc-ray/releases/tag/0.9.0)
used by the Puri todo application.

It is neither a RocRay fork nor a new Raylib host. The build downloads
RocRay's unmodified precompiled Zig host and Raylib archives, while the
checked-in Roc modules provide a smaller facade over their existing ABI:

```text
Roc application
    ↓
this Roc platform facade
    ↓
upstream RocRay libhost.a + local adapter
    ↓
upstream libraylib.a
```

The reduced [`App`](App.roc), [`AppConfig`](AppConfig.roc),
[`Color`](Color.roc), [`Draw`](Draw.roc), [`DrawHost`](DrawHost.roc),
[`Host`](Host.roc), [`Keys`](Keys.roc), [`Mouse`](Mouse.roc), and
[`main.roc`](main.roc) modules are derived from RocRay's package surface. They
preserve its 0.9 host ABI and frame-scoped drawing model while omitting
unrelated assets, audio, camera, sprite, tile-map, and physics APIs.

[`Clipboard.roc`](Clipboard.roc) and
[`roc_ray_adapter.c`](roc_ray_adapter.c) are local additions. The adapter
exports a narrow C ABI for:

- system clipboard text;
- minimum window sizing;
- disabling Raylib's default Escape-to-exit policy.

RocRay 0.9 itself now supplies nested frame-scoped scissor rectangles,
fractional two-axis scrolling, and keyboard-layout-aware Unicode text input.
Its host also uses Zig's `smp_allocator` outside explicit debug-allocator runs,
removing the severe diagnostic-allocation cost of the previous 0.8 bundle.

The remaining adapter functions call Raylib symbols already present in the
downloaded archive, so the upstream RocRay host does not need to be rebuilt.
The adapter unit test is in [`tests`](tests).

## Commands

```sh
make check
make test
make native-deps
```

`make native-deps` downloads the pinned release bundle into `.cache/`, extracts
only the native target inputs under `targets/`, and compiles the local adapter
beside them. Both directories are ignored build products.

RocRay is licensed under UPL-1.0. Raylib is licensed under the zlib/libpng
license. Their exact attribution, license text, and relationship to this
facade are recorded in
[`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md).
