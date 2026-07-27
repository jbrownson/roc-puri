# Third-party software

The original code in this repository is licensed under
[UPL-1.0](LICENSE). The following third-party software is included or
downloaded by the build.

## Clay 0.14

Roclay's conformance oracle vendors `clay.h` from
[Clay](https://github.com/nicbarker/clay), copyright (c) 2024 Nic Barker,
under the zlib/libpng license. The vendored source and its complete license
notice are under
[`roclay/tests/oracle/vendor/clay`](roclay/tests/oracle/vendor/clay).

Clay source is used only by the test oracle; it is not linked into Roclay or
the Todo application.

## RocRay 0.8.0 and raylib 6.0

The native example downloads the pinned
[RocRay 0.8.0](https://github.com/lukewilliamboswell/roc-ray/releases/tag/0.8.0)
host bundle. The checked-in platform facade also contains modules derived from
RocRay's package surface.

RocRay is copyright © 2024 Luke Boswell and subsequent authors and is licensed
under UPL-1.0. The downloaded bundle includes raylib 6.0, copyright (c)
2013-2026 Ramon Santamaria (@raysan5), under the zlib/libpng license.

The complete notices and the exact scope of the derived and downloaded
components are recorded in
[`roc-ray-platform/THIRD_PARTY_LICENSES.md`](roc-ray-platform/THIRD_PARTY_LICENSES.md).
Downloaded archives, extracted libraries, and build products are ignored and
are not stored in this repository.
