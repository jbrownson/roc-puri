# SpecConstr adds a phantom root argument after loop-carried reassignment

## Summary

For the reducer below, dev lowering gives `main` zero runtime arguments, while
SpecConstr lowering gives the same root one argument. Native
`--opt=size`/`speed` builds consequently return 1 instead of 0. Optimized
`wasm32` builds exit with status 1 without producing a module or diagnostic;
the WASM development build returns the correct result.

> **AI assistance:** The reducer, investigation, root-cause analysis, and this
> issue draft were prepared with OpenAI Codex 5.6 under the reporter's
> direction. All reported compiler results were reproduced locally.

## Versions and environment

The end-to-end native and WASM matrix was recorded on 2026-07-21 with this
published nightly:

```text
Roc compiler version release-fast-afef9119
commit afef9119194708c1bacebcef063e6bc39fc4a72f
```

- macOS 26.5.2 on Apple Silicon (`arm64`)
- x86-64 macOS binary run through Rosetta 2
- Node.js 26.4.0 for the WASM host

The compiler-tree test was separately reproduced with Zig 0.16.0 against
upstream `main` at
[`18ef7fc3`](https://github.com/roc-lang/roc/commit/18ef7fc30c0bc4957120e663f0183d296b981d5f)
on 2026-07-22.

## Reproduction

### Source reducer

The end-to-end observations used this 13-line application plus a minimal
platform with the contract `main! : () => I32`:

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

### Compiler-tree test

This is the primary reproduction and requires no custom platform. Append it to
`src/eval/test/lir_inline_test.zig`:

```zig
test "SpecConstr preserves root arity across loop-carried reassignment" {
    const allocator = std.testing.allocator;
    const source =
        \\main : I64
        \\main = {
        \\    var $x = 0
        \\    var $y = 0
        \\    for flag in [Bool.False] {
        \\        $y = if flag {
        \\            $x = 1
        \\            0
        \\        } else 0
        \\    }
        \\    $x + $y
        \\}
    ;

    var dev = try lowerModule(allocator, source, .none);
    defer dev.deinit(allocator);
    const dev_root = dev.lowered.lir_result.store.getProcSpec(
        try rootProc(&dev.lowered),
    );

    var optimized = try lowerModule(allocator, source, .wrappers);
    defer optimized.deinit(allocator);
    const optimized_root = optimized.lowered.lir_result.store.getProcSpec(
        try rootProc(&optimized.lowered),
    );

    try std.testing.expectEqual(
        dev.lowered.lir_result.store.getLocalSpan(dev_root.args).len,
        optimized.lowered.lir_result.store.getLocalSpan(optimized_root.args).len,
    );
}
```

Run only the new test:

```sh
zig build -j1 run-test-zig-lir-inline -- \
  --test-filter "SpecConstr preserves root arity across loop-carried reassignment"
```

On `18ef7fc3`, this exact pasted test is formatting-clean, compiles, and fails
with:

```text
expected 0, found 1
```

At this revision, `postCheckInlineModeForOpt` maps `--opt=dev` to `.none` and
`--opt=size`/`speed` to `.wrappers`, so the assertion directly compares the dev
and SpecConstr root arities:
[`src/cli/main.zig#L10310-L10316`](https://github.com/roc-lang/roc/blob/18ef7fc30c0bc4957120e663f0183d296b981d5f/src/cli/main.zig#L10310-L10316).

The structural assertion is intentional. Runtime test helpers allocate
zero-filled buffers for the arguments declared by the lowered root, which can
mask this bug by supplying zero for the phantom argument.

## Expected behavior

Optimization should preserve the requested root ABI, and this application
should return 0 on every backend.

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

<details>
<summary>Investigation notes and possible fix direction</summary>

### Generated native code

Disassembly shows that generated `roc_main` reads an argument which neither the
Roc source nor platform ABI declares:

```text
arm64:   str  w0, [sp, #0x10]
x86-64:  movl %edi, 0x10(%rsp)
```

The C host calls `roc_main()` with no argument. On both native targets the
undeclared register retains `argc == 1`, explaining the deterministic result.

### Likely root cause

My current reading points to `Cloner.cloneLoopValue` and `Cloner.putSubst` in
`src/postcheck/monotype_lifted/spec_constr.zig`:

- [`cloneLoopValue`](https://github.com/roc-lang/roc/blob/18ef7fc30c0bc4957120e663f0183d296b981d5f/src/postcheck/monotype_lifted/spec_constr.zig#L5480-L5578)
- [`dropCarriedBinderValue`](https://github.com/roc-lang/roc/blob/18ef7fc30c0bc4957120e663f0183d296b981d5f/src/postcheck/monotype_lifted/spec_constr.zig#L5657-L5670)
- [`putSubst`](https://github.com/roc-lang/roc/blob/18ef7fc30c0bc4957120e663f0183d296b981d5f/src/postcheck/monotype_lifted/spec_constr.zig#L7887-L7913)

1. `dropCarriedBinderValue(initial)` removes the pre-loop `binder_subst` entry,
   so the old value is not reused after reassignment.
2. The cloned loop parameter is installed with `putSubst(param.local,
   param_value)`.
3. `putSubst` updates `binder_subst` only for structured known values (`tag`,
   `record`, `tuple`, and `nominal`). An opaque scalar `.expr` receives only an
   exact-local substitution.
4. Reassigned references in the cloned body share the source binder identity
   but have different local IDs. They therefore miss the exact-local map and,
   because step 1 removed the binder-wide mapping, remain pointed at the old
   pre-loop local.
5. That old binding is absent from the cloned program. Capture recomputation
   treats the free local as a root capture, turning it into the phantom
   `roc_main` argument observed above.

The reduced program exercises the split-loop emission path. At `18ef7fc3`, that
path installs the replacement with `putSubst`, which appears insufficient for
the opaque scalar value in this case.

### Possible fix direction

When `cloneLoopValue` creates the fresh parameter value for a carried slot,
install a loop-specific binder-identity substitution from the initial carried
local to that fresh parameter, even when the value is an opaque `.expr`.
Record it in `changes` so the normal restore mechanism removes it after cloning.
The same invariant should be checked for whole-state parameters as part of the
fix.

A loop-specific change appears narrower than changing `putSubst` globally,
because ordinary opaque values currently avoid binder-wide substitution. I
have not implemented or validated this fix.

</details>

## Related issue search

The closest existing report is
[#10253](https://github.com/roc-lang/roc/issues/10253), which also described a
dev/optimized wrong-result discrepancy in SpecConstr. It was fixed by
freshening cloned binders, and that fix is already present in `afef9119`; this
reducer still fails on that build. Searches for `cloneLoopValue`,
`dropCarriedBinderValue`, `binder_subst`, loop-carried binder, phantom argument,
and optimized wrong result found no issue covering this failure mode as of
2026-07-22.
