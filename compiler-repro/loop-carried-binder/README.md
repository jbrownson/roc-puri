# SpecConstr loop-carried binder reproducer

This directory is a self-contained reproducer for a Roc optimizer correctness
bug. Submit this directory, not its parent: `compiler-repro` also contains an
unrelated specialization-performance investigation.

[`repro.roc`](repro.roc) is the only Roc application. It is 13 lines including
the app header:

```roc
app [main!] { pf: platform "./platform/main.roc" }

main! = || {
	var $x = 0
	var $y = 0
	for flag in [False] {
		$y = if flag {
			$x = 1
			0
		} else 0
	}
	$x + $y
}
```

The correct result is zero: the loop has one iteration, `flag` is `False`, and
the assignment `$x = 1` is never evaluated.

## Run everything

On Apple Silicon macOS with Roc, a C compiler, Zig, Node, and Rosetta installed:

```sh
make
```

The Makefile builds and runs the same application as native arm64, native
x86-64 under Rosetta, and WebAssembly. It keeps going through expected failing
commands so the complete matrix is visible in one run.

Individual targets are also available:

```sh
make native
make rosetta
make wasm
make clean
```

`ROC=/path/to/roc make` selects a particular compiler. Within this repository,
the Makefile automatically uses `../../.tools/roc/bin/roc` when present.

## Observed output

With `release-fast-afef9119`:

```text
== native arm64 ==
Expected: app returns 0
--opt=size     BUG: app returned 1 (expected 0)
--opt=speed    BUG: app returned 1 (expected 0)

== x86-64 under Rosetta ==
Expected: app returns 0
--opt=size     BUG: app returned 1 (expected 0)
--opt=speed    BUG: app returned 1 (expected 0)

== wasm32 ==
Expected: app returns 0
--opt=dev      OK: app returned 0
--opt=size     COMPILER BUG: exited 1 without a diagnostic or module
--opt=speed    COMPILER BUG: exited 1 without a diagnostic or module
```

The WASM development build provides the correct baseline because the minimal C
native platform is only compatible with optimized builds in this nightly.

## Compiler version

Verified with the latest published Unix and Windows Roc nightly on 2026-07-21:

```text
Roc compiler version release-fast-afef9119
upstream commit afef9119194708c1bacebcef063e6bc39fc4a72f
```

The bug was also reproduced against upstream `main` at
[`0cf9d218`](https://github.com/roc-lang/roc/commit/0cf9d21881b66c9a5694c7ab3e23823cf3da661d)
on 2026-07-22. A
[focused regression test](https://github.com/jbrownson/roc/commit/4da61571ffb3b24997d1da5e83ac1e1aa9f5cba5)
fails structurally: SpecConstr changes the root procedure from zero arguments
to one.

## What the Makefile builds

The platform is deliberately small and lives in [`platform`](platform):

- `native-host.c` calls `roc_main`, prints its `I32` result, and returns it as
  the process exit status.
- `wasm-host.c` exports the same call as `wasm_main`; `run-wasm.js` invokes it
  under Node.
- `main.roc` gives every target the identical `main! : () => I32` contract.

Generated host objects, SDK stubs, binaries, and caches are ignored under
`platform/targets` and `build`.

See [`ISSUE.md`](ISSUE.md) for the prepared upstream issue and root-cause
analysis.
