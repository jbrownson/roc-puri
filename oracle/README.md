# Clay behavioral oracle

`clay_oracle.c` is adapted from the oracle used by the Haskell Halay tests in
`prototype-haskell/halay/test`. It embeds an unmodified Clay 0.14 header and
prints element bounding boxes in a small line-oriented format. Roclay never
links against Clay; this executable is an independent reference process.

Build it and print the fixed corpus with:

```sh
make oracle
```

The modes retained from Halay are:

- no argument: fixed layout and text cases;
- `--stdin`: generated flat containers;
- `--tree-stdin`: generated recursive layout trees;
- `--tree-debug-stdin`: recursive trees with an extra debug lookup;
- `--text-stdin`: generated text wrapping cases.

Each stdin mode accepts whitespace-delimited cases and emits one line per
named element or text command. These protocols are intended for a persistent
oracle process during deterministic fuzzing, avoiding a C compilation for
each case.

The text and tree protocols reset Clay's text-measurement cache between wire
rows. Each row is an independent layout, so cache state—and especially a cache
key collision in an earlier case—must not change a later oracle result.

The vendored header is Clay 0.14 by Nic Barker and retains its zlib license in
`vendor/clay/LICENSE.md`.
