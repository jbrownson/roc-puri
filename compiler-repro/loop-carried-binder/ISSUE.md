# `--opt=size`/`speed` leak a reassigned loop variable into the app ABI

## Summary

SpecConstr can leave a reference to a removed pre-loop local when two mutable
variables are carried through a `for` loop and one is conditionally reassigned
inside the expression assigned to the other.

LLVM optimized builds return a value sourced from an undeclared ABI argument.
Optimized `wasm32` builds exit with status 1 without producing a module or
diagnostic. The WASM development build returns the correct result.

## Roc version

Latest published nightly as of 2026-07-21:

```text
Roc compiler version release-fast-afef9119
commit afef9119194708c1bacebcef063e6bc39fc4a72f
```

The standalone target matrix below was verified with this nightly.

The bug was also reproduced against upstream `main` at
[`18ef7fc3`](https://github.com/roc-lang/roc/commit/18ef7fc30c0bc4957120e663f0183d296b981d5f)
on 2026-07-22. A focused structural regression test demonstrates that lowering
without SpecConstr keeps the root procedure at zero arguments, while lowering
with SpecConstr introduces one. The failing test is available in
[`4da61571`](https://github.com/jbrownson/roc/commit/4da61571ffb3b24997d1da5e83ac1e1aa9f5cba5).

## Reproduction

The attached `loop-carried-binder` directory is self-contained. On Apple
Silicon macOS with Roc, Zig, Node, and Rosetta installed:

```sh
make
```

The Makefile builds and runs the application as arm64 macOS, x86-64 macOS under
Rosetta, and wasm32. Each backend uses the same platform contract,
`main! : () => I32`.

The entire Roc application is 13 lines:

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

The correct result is zero. `flag` is `False`, so `$x = 1` is unreachable.

## Actual results

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

A wasm32 control application using the identical platform and `main! = || 0`
builds successfully with `--opt=size`, so the host is not the optimized-build
failure.

## Generated native code

Disassembly shows that generated `roc_main` reads an argument which neither the
Roc source nor platform ABI declares:

```text
arm64:   str  w0, [sp, #0x10]
x86-64:  movl %edi, 0x10(%rsp)
```

The C host calls `roc_main()` with no argument. On both native targets the
undeclared register retains `argc == 1`, explaining the deterministic result.

## Root cause

This occurs in `src/postcheck/monotype_lifted/spec_constr.zig`, in
`Cloner.cloneLoopValue`.

1. `dropCarriedBinderValue(initial)` removes the pre-loop `binder_subst` entry,
   correctly preventing the old value from being reused after reassignment.
2. The cloned loop parameter is installed with `putSubst(param.local,
   param_value)`.
3. `putSubst` deliberately updates `binder_subst` only for structured known
   values (`tag`, `record`, `tuple`, and `nominal`). An opaque scalar `.expr`
   receives only an exact-local substitution.
4. Reassigned references in the cloned body share the source binder identity
   but have different local IDs. They therefore miss the exact-local map and,
   because step 1 removed the binder-wide mapping, remain pointed at the old
   pre-loop local.
5. That old binding is absent from the cloned program. Capture recomputation
   treats the free local as a root capture, turning it into the phantom
   `roc_main` argument observed above.

The reduced program exercises the split-loop emission path. In current `main`,
that path still installs the replacement with `putSubst`, which is insufficient
for the opaque scalar value in this case.

## Suggested direction

When `cloneLoopValue` creates the fresh parameter value for a carried slot,
install a loop-specific binder-identity substitution from the initial carried
local to that fresh parameter, even when the value is an opaque `.expr`.
Record it in `changes` so the normal restore mechanism removes it after cloning.
The same invariant should be checked for whole-state parameters as part of the
fix.

This should remain loop-specific rather than changing `putSubst` globally;
the latter intentionally avoids binder-wide substitution for ordinary opaque
values.

## Related issue search

The closest existing report is
[#10253](https://github.com/roc-lang/roc/issues/10253), which also described a
dev/optimized wrong-result discrepancy in SpecConstr. It was fixed by
freshening cloned binders, and that fix is already present in `afef9119`; this
reducer still fails on that build. Searches for `cloneLoopValue`,
`dropCarriedBinderValue`, `binder_subst`, loop-carried binder, phantom argument,
and optimized wrong result found no issue covering this failure mode.
