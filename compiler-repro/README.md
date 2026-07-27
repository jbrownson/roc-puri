# Historical slow specialization with callback-parameterized recursive layout

This repository intentionally preserves Roclay's continuation-based encoding
while the new Roc compiler's specialization behavior is investigated.

On an Apple M3 Pro with compiler `release-fast-afef9119`, three warm `roc build`
runs against the same tiny C platform produced:

| Application | Build time | File bytes | `__text` bytes | Symbols | Roc procedures |
| --- | ---: | ---: | ---: | ---: | ---: |
| `RocSpecializationMinimal` | 0.08 s | 49,792 | 116 | 8 | 0 |
| `RocSpecializationRoclay` | 8.29 s | 135,584 | 83,512 | 87 | 21 |
| `RocSpecializationPuri` | 11.23 s | 135,600 | 82,608 | 87 | 21 |

The last two applications constructed and placed the same two-spacer layout.
At the time, they differed only in the state parameter threaded through
`Roclay.Layout(state)`: the Roclay probe used `{}`, while the Puri probe used
`Puri.Frame({}, {})`, a record containing the render value and six handler
functions.

Changing that state added roughly three seconds of specialization while
producing the same symbol and Roc-procedure counts and a slightly smaller text
section. This pointed to compiler work that was not emitted as duplicated code.

The probes now follow Roclay's current composable-output API:
`Layout(output)` placement returns an output with `default` and `plus`, rather
than transforming an input state. The table is retained as historical context,
not as current-nightly performance data.

Run the comparison with:

```sh
make specialization-repro
```

The applications under [`specialization`](specialization) are deliberately
small entry points over the real `Roclay`, `Puri`, and `PuriHandler` packages.
A standalone minimized compiler reproducer can be derived from these files
before filing an upstream issue.
