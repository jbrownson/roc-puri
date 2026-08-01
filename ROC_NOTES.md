# Roc evaluation notes

This records language, compiler, platform, and ecosystem friction encountered
while building Puri and Roclay. Entries distinguish reproduced limitations,
platform/package limitations, deliberate language tradeoffs, and open questions
where we may simply be missing the intended Roc pattern.

This file was generated and maintained by Codex as the work progressed. Unlike
the core Puri modules, it has not received careful line-by-line author review;
its claims should be treated as working observations to verify rather than an
authoritative account of Roc.

The workspace targets nightlies of the new Zig-based compiler. Alpha4 behavior
is useful historical evidence, but is not assumed to carry over.

## Open findings

### Directory-qualified local modules are missing in the Zig compiler

**Category:** reproduced compiler limitation or regression

Alpha4 supported mapping qualified imports to source subdirectories. Roc's
official
[`ImportFromDirectory` example](https://github.com/roc-lang/examples/blob/1d180e9226610f1ce998ffc089d74961ee379752/examples/ImportFromDirectory/README.md)
uses `import Dir.Hello` for `Dir/Hello.roc`, and
[`roc-lang/roc#3451`](https://github.com/roc-lang/roc/issues/3451) treated a
nested-directory resolution failure as a compiler bug.

With the 2026-07-25 Zig nightly used here (`release-fast-b6cdced9`), neither a
`package [Src.Widget]` manifest nor `import Src.Widget` finds
`Src/Widget.roc`. The former looks beside `main.roc`; the latter treats `Src`
as an external package qualifier.

That matches the current implementation:

- [`module_discovery.zig`](https://github.com/roc-lang/roc/blob/main/src/compile/module_discovery.zig)
  discovers only unqualified imports as local sibling modules.
- [`module_path.zig`](https://github.com/roc-lang/roc/blob/main/src/base/module_path.zig)
  splits a dotted import into package qualifier and module name.

**Impact here:** package modules cannot live under `src/` while `main.roc`
remains at the package root. Making `src/` the package root merely changes
dependency paths to `../puri/src/main.roc`; it does not separate the manifest
from the flat source package. This workspace follows the current official
pattern used by
[`unicode/package`](https://github.com/roc-lang/unicode/tree/main/package) and
[`basic-cli/platform`](https://github.com/roc-lang/basic-cli/tree/main/platform).

**Follow-up:** ask whether directory-qualified local modules are planned for
the Zig compiler and file a small issue if this is not already tracked.

### Platform composition and extension are awkward

**Category:** language/ecosystem design concern, plus RocRay API limitations

Platforms provide an explicit, reproducible boundary for effects and native
integration. The awkward case is a reusable library needing capabilities the
selected platform does not expose, or several libraries bringing independently
designed capability sets.

The Todo needed clipboard access, nested clipping, fractional two-axis
scrolling, multi-click counts, minimum window sizing, and control over
Raylib's Escape-to-exit behavior. Raylib provides all of them, but RocRay's Roc
surface does not.

[`roc-ray-platform`](roc-ray-platform/README.md) therefore downloads RocRay's
precompiled host and Raylib libraries, declares a replacement Roc platform
surface, and links a small C adapter against symbols already present in those
archives:

```text
application
    -> local Roc platform facade
    -> upstream RocRay host + local C adapter
    -> Raylib
```

This works, but extending a platform is not like extending an ordinary library.
The platform header, exposed modules, hosted-function ABI, native artifacts,
and application must agree, so reusing the host requires preserving that
agreement manually.

Puri stays platform-independent by accepting capabilities as functions and
records; for example, its line editor receives clipboard operations in its
ephemeral interaction description. That keeps widgets portable but moves
platform adaptation into each application/backend integration.

The same boundary prevents a natural `puri-rocray` integration package. Its
modules would need to import both Puri and platform-exposed types such as
`rr.Host`, `rr.Color`, and `rr.Draw`. With the current Zig compiler, a package
module cannot see the consuming application's `rr` platform alias, and a
package header cannot declare a platform dependency. A small probe failed with
an undeclared `Host` when `rr` existed in the application header; adding
`rr: platform "..."` to the package header was rejected as an invalid package
dependency.

Consequently, [`RocRayInput`](todo/RocRayInput.roc) and
[`RocRayCanvas`](todo/RocRayCanvas.roc) remain incorrectly app-local. The
available workarounds all distort the intended boundary: move reusable Puri
integration into the platform, duplicate platform types behind a neutral
snapshot and pass every hosted effect as a capability, or leave the adapters
in each application. A backend adapter should be an ordinary reusable package;
selecting one platform should not prevent packages from adapting its public
Roc API.

Open questions:

- Can platforms be extended or composed without taking ownership of a new
  platform package and host ABI?
- Is the inability of a package to import the application's selected platform
  API intended, or a missing piece of the Zig compiler's package system?
- How should independently developed packages share platform-provided nominal
  types and overlapping capability sets?
- Which parts of this workaround reflect ecosystem immaturity, and which
  follow from the platform model itself?

### Higher-kinded abstraction is missing from finally-tagless code

**Category:** deliberate language-design tradeoff exposed by Puri

#### Handlers

Haskell Puri parameterizes a handler by an application-chosen effect
constructor:

```haskell
type Handler actionM = Event -> Maybe (actionM ())
```

`actionM` can be production effects or a pure State/Writer interpreter in
tests. Puri can sequence those actions without knowing their representation.

Roc's `=>` marks a function as effectful but does not name an effect vocabulary
or abstract over its interpreter. The Roc port therefore chooses a concrete
State-like representation:

```roc
HandleEvent(state, event) : state, event => HandleResult(state)

Clipboard(state) : {
    read! : state => { state : state, text : Str },
    write! : state, Str => state,
}
```

This is pure-testable, but every action must thread the chosen `state`.
Capturing the model in each callback would instead capture a per-frame snapshot
and prevent independent transitions from composing. Building action commands
for later interpretation would recover generality by replacing the direct
interface with an initial encoding.

Button makes the tradeoff concrete:

```roc
Action(state) : state => state

Description(state) : {
    focused : Bool,
    request_focus! : Action(state),
    activate! : Action(state),
}
```

The button can sequence arbitrary caller-defined transitions:

```roc
focused_state = (description.request_focus!)(state)
Handled((description.activate!)(focused_state))
```

This corresponds to Haskell's `buttonFocus *> buttonActivate`. Roc can define
one concrete State monad and give it `map`/`bind`, but Button would then be
fixed to that representation. The missing abstraction is the ability to
parameterize Button over an unknown `actionM` and require operations on that
type constructor.

Rendering is a separate effect family in Haskell:

```haskell
buttonFocus    :: actionM ()
buttonActivate :: actionM ()
buttonContent  :: Bool -> Rect -> renderM ()
```

In Roc, application actions and direct rendering both use `=>`. `content!` is
honestly effectful—it draws and may place more widgets—but the type system
cannot distinguish the application's `actionM` from the renderer's `renderM`.
Both ultimately share the platform-selected ambient effect vocabulary.
Separately, its named content record makes `focused` and `hovered` visible at
call sites instead of passing two easily transposed booleans.

#### Rendering

Haskell can abstract over a carrier of kind `Type -> Type`:

```haskell
class Monad m => Canvas m paint where
    fillRect :: Rect -> paint -> m ()
```

The carrier may draw directly, record commands, maintain interpreter state, or
return values used by later operations. Roc cannot parameterize over `m`, so
Puri uses a narrower first-order result:

```roc
Canvas.Operations(result, paint) : {
    fill_rect! : Rect, paint => result,
    # ...
}
```

Frames combine results through conventional methods:

```roc
where [
    result.default : result,
    result.plus : result, result -> result,
]
```

RocRay draws directly and returns a trivial result. Tests return command
fragments whose `plus` concatenates recordings. This remains finally tagless
and is enough when operations have unit-like useful results, but it is not
equivalent to `m a`:

- `result` cannot vary with an operation's returned value;
- value-dependent sequencing needs callbacks, explicit threading, or a
  concrete effect encoding; and
- the higher-level constraint cannot itself be named and reused.

Roc's effectful functions, structural constraints, and capability passing
cover the individual cases. Puri exposes where they stop scaling to a family
of interpreters. Keeping the monoidal result visible is both useful for this
prototype and more honest than hiding the limitation behind a retained command
tree.

### Optimized specialization was impractical

**Category:** resolved compiler performance bug amplified by higher-order
composition

With `release-fast-b6cdced9`, the Todo speed build exceeded 13 GB and was
OOM-killed after roughly ten minutes. A dependency-free reduction showed the
cost multiplying across generic Roclay tree passes and the size of Puri's
concrete frame/event types, even though the layout solver never inspected the
generic output. Stack samples tied that reduction to the full application.

`release-fast-f5556d8c` fixes the explosion: the full Todo now builds in about
17 seconds at 904 MB peak, while the reduction's successful runs fall from
about 23 seconds and 8 GB to about 1.3 seconds. The historical reductions
were kept locally while investigating but are intentionally not part of this
design-prototype repository.

### Speed builds nondeterministically crash the compiler

**Category:** compiler bug (memory-layout-dependent crash), reproduced

On `nightly-2026-August-01-1c1cecc`, the final reduced speed build crashed 2 of
20 identical attempts with the compiler's SIGSEGV banner. Earlier reduction
runs also occasionally produced SIGABRT or hung. `roc check` and dev builds
consistently succeed. It also reproduced with `-j1`, while lldb mostly
suppressed it, suggesting a memory-layout-sensitive compiler defect rather
than a source error or ordinary worker race.

The remaining program is a recursive generic layout record holding output
closures, a constrained recursive fold, a nominal handler over record state,
and three layout nodes. The Clay solver, tree passes, event unions, and other
Puri details are gone. The self-contained source and reproduction instructions
are in [the public Gist](https://gist.github.com/jbrownson/b6d87338d63167c705770e68750fada1),
and the compiler report is [roc-lang/roc#10527](https://github.com/roc-lang/roc/issues/10527).

### Optional domain state uses descriptive tag unions

**Category:** intentional language convention that is initially non-obvious

Roc has no standard `Maybe` or `Option`. `Try` describes failure; ordinary
state that may be inactive is normally modeled with domain-specific tags.

For example, Haskell might use `Maybe ActiveDrag`. Puri flattens absence and
the active variants into one type:

```roc
Drag := [
    NotDragging,
    CharacterDrag,
    WordDrag({ origin : TextRange }),
    AllDrag,
]
```

`NotDragging` communicates what absence means and avoids a nested
`Dragging(ActiveDrag)` match. `WordDrag` carries the original word range so a
drag can cross it and change direction.

Anonymous unions such as `[Some(value), None]` are still available and this
workspace uses them for mechanically optional values. They are a convention
built from ordinary tags rather than a built-in generic optional type. The
choice between domain tags and `Some`/`None` is initially less obvious than a
standard `Maybe`/`Option` convention.

### Groups of method constraints cannot be named

**Category:** language expressiveness and API readability

Generic geometry repeats scalar requirements such as:

```roc
where [
    a.plus : a, a -> a,
    a.minus : a, a -> a,
    a.is_lt : a, a -> Bool,
    a.is_gt : a, a -> Bool,
]
```

Puri and Roclay similarly repeat the `default`/`plus` requirements shown
above. Roc's
[`where` documentation](https://github.com/roc-lang/roc/blob/main/docs/langref/types.md#where-clauses)
provides no way to name either group.

The new parser still contains an alias form:

```roc
Sort(a) : a where [a.order : a, a -> Ordering]
sort : List(elem) -> List(elem) where [elem.Sort]
```

The checker deliberately reports it as
[`Unsupported Where Clause`](https://github.com/roc-lang/roc/blob/main/src/check/report.zig#L2008-L2036);
the syntax belonged to the removed abilities system and is not usable today.

The alternatives are to repeat constraints, choose a concrete type, or pass an
explicit operations dictionary through every call. Geometry repeats the
constraints to remain generic.

Puri instead centralizes a prototype-wide `F32` choice in
`puri.Geometry.Scalar`. A backend-selectable scalar would have to propagate
through placements, pointer events, Canvas, text metrics, and nearly every
widget, along with repeated arithmetic and ordering constraints. Since Roclay
and the current backend already use `F32`, that machinery would obscure the
state and rendering experiment without exercising the polymorphism. This is a
prototype tradeoff, not a claim that Puri fundamentally requires `F32`.

### Compiler derivation is a closed set

**Category:** language-design tradeoff and missing extensibility

The Zig compiler can synthesize six recognized methods: `is_eq`, `to_hash`,
`parser_for`, `encoder_for`, `map`, and `map!`. Anonymous structural types
receive supported derivations automatically; a nominal type opts in with `_`:

```roc
Point := { x : F32, y : F32 }.{
    is_eq : _
    to_hash : _
}
```

Todo uses this supported mechanism for its `FocusTarget` and private
focus-location types, replacing otherwise repetitive tag-by-tag comparisons.

Unlike Haskell deriving, this mechanism is not library-extensible. Roc cannot
derive `plus`, `default`, ordering, or a project-defined method by recursively
using component methods.

`Frame.plus` is a concrete missing case:

```roc
plus = |earlier, later| {
    placement_result: earlier.placement_result + later.placement_result,
    handler: earlier.handler + later.handler,
}
```

`Handler` contains a function, so structural equality for `Frame` is not
possible. That is unrelated to combination: `Handler` explicitly defines
`plus`, and the placement-result constraint supplies the other field's `plus`.
`Frame.plus` must still be written by hand because `plus` is outside the
compiler's closed derivation set.

### Default values use zero-argument functions

**Category:** language convention and open question

Roc's standard `default` protocol represents an identity as a function:

```roc
default : () -> U8
default = || 0
```

Puri follows it with `Handler.default()` and `Frame.default()`. Calling a
constrained static method also requires a capitalized local type alias:

```roc
default : () -> Frame(placement_result, state, event)
    where [placement_result.default : placement_result]
default = || {
    PlacementResult : placement_result
    {
        placement_result: PlacementResult.default(),
        handler: Handler.default(),
    }
}
```

`PlacementResult` is only a transparent alias for the lowercase type variable.
It exists because static method syntax requires a capitalized type name;
Roc's `List.sum` uses the same `Item : item` pattern.

An immutable constant would be more direct, but would not satisfy generic code
expecting the standard function-shaped method. The runtime cost should inline
away, so the remaining question is why the ecosystem universally prefers a
function—whether fresh construction is important enough to justify the
readability cost in constant cases.

### Canonical formatting can force awkward source structure

**Category:** compiler/tooling limitation

Button accepts Enter or Space. A shared nested pattern would be concise:

```roc
Key({ state: KeyDown, key: Named(Enter | Space), .. })
```

The compiler parses it but rejects the nested alternative as unimplemented.
Moving the alternative to the top level compiles, but `roc fmt` forces the
whole branch onto one long line:

```roc
Key({ state: KeyDown, key: Named(Enter), .. }) | Key({ state: KeyDown, key: Named(Space), .. }) if description.focused => Handled((description.activate!)(state))
```

An extra inner `match` produces shorter formatting only by obscuring that the
two keys are alternatives for the same event. Puri keeps the long canonical
form rather than restructuring the program for the formatter.

The formatter has also emitted trailing whitespace after an ordinary
multiline `binding =`, conflicting with `git diff --check`. That call site had
to be factored into extra names so the canonical form stayed on one line.
These are small examples of irrelevant program structure being chosen to
satisfy the formatter.

## Resolved ecosystem transitions

### The official Unicode package migrated to the Zig compiler

When Puri's editor was first written,
[`roc-lang/unicode`](https://github.com/roc-lang/unicode) still used alpha4
syntax. Its current `main` now checks with this workspace's Zig nightly.

Puri retains its small package-private [`Utf8`](puri/Utf8.roc) module because
the prototype only promises valid code-point boundaries, not grapheme-aware
editing. A fuller editor should revisit the official package rather than grow
this helper into a competing Unicode library.

## Resolved compiler bugs

### Optimized builds changed layout behavior

An optimized build placed a trailing Todo button off-screen while development
mode was correct. Reduction showed that SpecConstr added a phantom argument to
a zero-argument root after loop-carried reassignment:

- [`roc-lang/roc#10317`](https://github.com/roc-lang/roc/issues/10317)
- fixed by [`roc-lang/roc#10336`](https://github.com/roc-lang/roc/pull/10336)

The bug reproduced on native ARM64, x86-64 under Rosetta, and the WASM compiler
path. The reducer was removed after the fix landed and the workspace adopted a
newer nightly.
