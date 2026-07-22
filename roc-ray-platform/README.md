# Narrow RocRay platform facade

This directory describes the subset of the
[RocRay 0.8](https://github.com/lukewilliamboswell/roc-ray/releases/tag/0.8.0)
platform ABI used by Puri's native example. It links to the unmodified prebuilt
RocRay host and Raylib 6 archives downloaded by `make native-deps`; those
generated target files are ignored by Git.

The facade intentionally contains no renderer implementation. Drawing still
goes directly from Roc through RocRay's hosted symbols into Raylib. Limiting
the exposed Roc modules keeps Puri independent of RocRay's game/asset APIs and
provides a small platform surface. The local hosted adapter adds the system
clipboard, minimum window sizing, nested Raylib scissoring, click counting, and
Escape-key policy that the todo example needs without rebuilding the upstream
host.

RocRay is licensed under UPL-1.0. Raylib is licensed under the zlib/libpng
license. Their sources and license texts are available from the linked RocRay
release and [Raylib repository](https://github.com/raysan5/raylib).
