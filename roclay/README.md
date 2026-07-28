# Roclay

Roclay is a continuation-based Roc port of Clay 0.14's layout behavior. It
solves rows, columns, padding, gaps, fixed/fit/fill/percent sizing, min/max
constraints, alignment, aspect ratios, clipped child offsets, intrinsic
leaves, and width-sensitive text.

Nic Barker's [How Clay's UI Layout Algorithm Works](https://youtu.be/by9lQvpvMIc)
is a visual introduction to the original layout algorithm.

Unlike Clay, Roclay does not produce render commands. `place!` solves directly
at a known root placement, and final entry, leaf, line, exit, and controlled
container placements are delivered to caller-supplied functions:

```roc
Place(output) : Placement => output
PlaceKids(output) : Point => output
PlaceInner(output) : () => output
Around(output) : Placement, PlaceInner(output) => output
PlaceContainer(output) : Placement, ContainerInfo, PlaceKids(output) => output
PlaceTextLine(output) : U64, Str, Placement => output
```

`around` transparently wraps a node's placement continuation without adding a
layout node or changing its geometry. It can inspect the settled placement,
run work before the subtree, decide when or whether to invoke `PlaceInner`,
transform the subtree's output, and run work afterward. Calling the
continuation more than once repeats its placement effects. `before` and
`after` are the convenient leading and trailing special cases derived from
`around`. This preserves Clay's rendering order without prescribing rendering:
background-like effects can run before a subtree, border-like effects can run
after it, and handler-producing output can be transformed as a unit.

This is not only a different rendering API. Clay render commands carry element
IDs and opaque user data so later code can relate output commands to their
originating elements. Roclay keeps that relationship lexical: the function
attached to a node is called with that node's settled geometry. Puri can
therefore render and construct handlers without assigning identities to layout
outputs, building a command tree, or performing a lookup after layout.

`measure` is the optional content-sizing path: it returns a preferred size and
a placement continuation for callers that do not already know the root size.
Both terminal operations require the output's conventional `default` and
`plus` methods and combine callback output in traversal order. A native
renderer can perform effects immediately and return a trivial output; tests
return recordings.

## Dependency

[`main.roc`](main.roc) depends only on the sibling geometry project:

```roc
package [Roclay] { geometry: "../geometry/main.roc" }
```

That relative value can become a package URL if Roclay is published as its own
repository.

## Files

- [`Roclay.roc`](Roclay.roc) is the compact public facade.
- [`RoclayInternal.roc`](RoclayInternal.roc) contains the private constraint,
  wrapping, and placement passes.
- [`tests`](tests) contains the recording interpreter, executable placement
  tests, generated conformance adapters, and its private native test platform.
- [`tests/oracle`](tests/oracle) embeds an unmodified Clay 0.14 header as an
  independent behavioral oracle.
- [`tests/tools`](tests/tools) contains deterministic generators and the tree
  reducer.

## Commands

```sh
make check
make test
make docs
make conformance
make oracle
make fuzz-flat
make fuzz-tree
make fuzz-text
```

The default deterministic fuzz runs cover 250 flat layouts, 50 recursive
trees, and 250 text layouts. Counts and seeds are configurable:

```sh
make fuzz-tree TREE_FUZZ_CASES=250 TREE_FUZZ_SEED=2
make fuzz-text TEXT_FUZZ_CASES=1000 TEXT_FUZZ_SEED=1
```

Generated Roc programs and replay corpora are ignored build products. A known
failing recursive case can be reduced from the Roclay directory with:

```sh
python3 tests/tools/reduce_tree_conformance.py \
  --seed 402607220048 --case 35 \
  --min-delta 0.5 --max-delta 0.85
```
