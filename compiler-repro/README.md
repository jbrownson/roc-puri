# Slow specialization with callback-parameterized recursive layout

This repository intentionally preserves Roclay's continuation-based encoding
while the new Roc compiler's specialization behavior is investigated.

On an Apple M3 Pro with compiler `release-fast-afef9119`, three warm `roc build`
runs against the same tiny C platform produced:

| Application | Build time | File bytes | `__text` bytes | Symbols | Roc procedures |
| --- | ---: | ---: | ---: | ---: | ---: |
| `RocSpecializationMinimal` | 0.08 s | 49,792 | 116 | 8 | 0 |
| `RocSpecializationRoclay` | 8.29 s | 135,584 | 83,512 | 87 | 21 |
| `RocSpecializationPuri` | 11.23 s | 135,600 | 82,608 | 87 | 21 |

The last two applications construct and place the same two-spacer layout. They
differ only in the state parameter threaded through `Roclay.Layout(state)`:
the Roclay probe uses `{}`, while the Puri probe uses `Puri.Frame({}, {})`, a
record containing the render value and six handler functions.

Changing that state adds roughly three seconds of specialization while
producing the same symbol and Roc-procedure counts and a slightly smaller text
section. This points to compiler work that is not emitted as duplicated code.

Run the comparison with:

```sh
make specialization-repro
```

The applications are deliberately small entry points over the real `Roclay`,
`Puri`, and `PuriHandler` modules. A standalone minimized compiler reproducer
can be derived from these files before filing an upstream issue.
