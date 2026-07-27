# Roc evaluation notes

This is a running record of language, compiler, platform, and ecosystem friction
encountered while building Puri and Roclay. It is not intended to be a list of
general complaints about Roc. Entries should distinguish:

- a reproduced compiler bug or missing implementation;
- a limitation of a particular platform or package;
- a language-design tradeoff that the project makes concrete; and
- an open question for which we may simply be missing the intended Roc pattern.

The workspace targets nightlies of the new Zig-based compiler. Behavior from
the alpha4 Rust compiler is useful historical evidence, but is not assumed to
work in the new compiler.

## Open findings

### Directory-qualified local modules are missing in the Zig compiler

**Category:** reproduced compiler limitation or regression

The alpha4 compiler supported mapping a qualified local import to a source
subdirectory. Roc's official
[`ImportFromDirectory` example](https://github.com/roc-lang/examples/blob/1d180e9226610f1ce998ffc089d74961ee379752/examples/ImportFromDirectory/README.md)
uses:

```roc
import Dir.Hello
```

for `Dir/Hello.roc`. Roc also treated a nested-directory resolution failure as
a compiler bug in
[`roc-lang/roc#3451`](https://github.com/roc-lang/roc/issues/3451).

With the 2026-07-25 Zig nightly used by this workspace,
`release-fast-b6cdced9`, both of these small arrangements fail:

```text
main.roc              main.roc
Src/Widget.roc        Src/Widget.roc

package [Src.Widget]  package []
                      import Src.Widget
```

The first looks for `Widget.roc` beside `main.roc`. The second treats `Src` as
a package qualifier and looks for a package named `Src`, rather than loading
`Src/Widget.roc`.

This matches the current compiler implementation:

- [`module_discovery.zig`](https://github.com/roc-lang/roc/blob/main/src/compile/module_discovery.zig)
  discovers only unqualified imports as local sibling modules and sends every
  import with a qualifier down the external-package path.
- [`module_path.zig`](https://github.com/roc-lang/roc/blob/main/src/base/module_path.zig)
  splits any dotted import such as `Src.Widget` into the qualifier `Src` and
  module `Widget`.

This therefore appears to be an unimplemented old feature or a regression in
the new compiler, not a fundamental Roc rule.

**Impact here:** a package cannot keep `main.roc` at its package root while
putting its sibling modules in `src/`. The clean workaround is to put the
entire package root in `src/`, including `src/main.roc`, and have dependents
refer to (for example) `../puri/src/main.roc`. Current official projects use
the same general pattern with
[`package/main.roc`](https://github.com/roc-lang/unicode/blob/main/package/main.roc)
and
[`platform/main.roc`](https://github.com/roc-lang/basic-cli/blob/main/platform/main.roc).

**Follow-up:** check with the Roc team whether directory-qualified local
modules are planned for the Zig compiler, and file a small issue if this is not
already tracked.

### Platform composition and extension are awkward

**Category:** language/ecosystem design concern, mixed with limitations of the
current RocRay platform

Platforms give an application an explicit, reproducible boundary for effects
and native integration. That is valuable. The difficult part is what happens
when a reusable library needs capabilities that the chosen platform does not
already expose, or when several libraries bring independently designed sets of
capabilities.

The Todo example needed functionality that RocRay's Roc API did not expose:

- clipboard access;
- nested clipping;
- fractional two-axis scrolling;
- multi-click counting;
- minimum window sizing; and
- control over Raylib's Escape-to-exit behavior.

These are available in Raylib, so
[`roc-ray-platform`](roc-ray-platform/README.md) downloads RocRay's precompiled
host and native libraries, declares a replacement Roc platform surface, and
adds a small C adapter linked against symbols already in those libraries. This
works, but it is a brittle amount of machinery for incrementally extending a
platform:

```text
application
    -> local Roc platform facade
    -> upstream precompiled RocRay host + local C adapter
    -> Raylib
```

A platform is not merely a library dependency whose API can be extended from
Roc. The platform header, exposed modules, hosted-function ABI, native
artifacts, and application all have to agree. Reusing the upstream host while
changing the Roc-facing platform requires us to understand and preserve that
agreement manually.

Puri avoids depending on any one platform by accepting capabilities as
ordinary functions and records. For example, the line editor receives
clipboard `read!` and `write!` functions as part of its ephemeral interaction
description. This is workable and keeps Puri portable, but it pushes platform
adaptation into every application/backend integration. It remains unclear what
the intended scalable Roc pattern is when independently developed libraries
need partially overlapping effect vocabularies, or when an application wants
to combine platform functionality that was not designed together.

Questions to carry into a community review:

- Is there a supported way to extend or compose platforms without taking
  ownership of a new platform package and host ABI?
- How are platform-provided nominal types shared between independently
  developed packages without forcing all of them to depend on one platform?
- What conventions keep capability-passing APIs from duplicating large effect
  records throughout an ecosystem?
- Which parts of our RocRay workaround are temporary ecosystem immaturity, and
  which are consequences of the platform model itself?

### Lack of higher-kinded types limits the finally-tagless abstraction

**Category:** deliberate language-design tradeoff exposed by Puri

Puri's event handlers make the limitation especially concrete. In Haskell, a
handler is parameterized by an application-chosen effect constructor:

```haskell
type Handler actionM = Event -> Maybe (actionM ())
```

`actionM` can be the production application's effects or a pure State/Writer
interpreter in tests. Puri can sequence those actions without knowing their
representation.

Roc's `=>` marks a function as effectful, but does not name an effect vocabulary
or abstract over how it is interpreted. A platform supplies the primitive
external effects, and capability records can pass particular operations around,
but there is no type parameter corresponding to `actionM`. The Roc port must
choose a concrete representation:

```roc
HandleEvent(state, event) : state, event => HandleResult(state)

Clipboard(state) : {
    read! : state => { state : state, text : Str },
    write! : state, Str => state,
}
```

This is the State monad written out inline. It is pure-testable and works, but
fixes the effect representation and requires application state to be threaded
through every operation. Capturing the model in each callback would instead
capture a per-frame snapshot and would prevent independent state transitions
from composing. Building commands for a later interpreter would recover
generality by abandoning Puri's finally-tagless design for an initial encoding.

The button's focus request is a small example of both the generality and the
awkwardness:

```roc
Action(state) : state => state

Description(state) : {
    focused : Bool,
    request_focus! : Action(state),
    activate! : Action(state),
}
```

Puri does not define what requesting focus or activating the button means.
Either application-supplied function might update one field of its state,
coordinate several parts of the application, perform external effects, or even
launch a rocket before returning the next state. The button can correctly
sequence `request_focus!` and `activate!` without retaining state or knowing
either implementation. That is the useful generality of capability passing.

At the same time, the type must commit to the concrete `state => state`
encoding. The `!` says only that the function may perform effects; it does not
name which effects it requires, and those external capabilities ultimately
come from the application's platform. Puri cannot instead quantify over an
application-selected `m` and ask merely for `request_focus : m ()`. Thus a
simple, nicely abstract widget action still exposes both manual State threading
and Roc's ambient platform effect boundary.

The button's `content!` has a `!` for a different reason: placing the content
performs immediate rendering and may place further widgets. This agrees with
the Haskell Puri interface, where the three operations inhabit two distinct
effect constructors:

```haskell
buttonFocus    :: actionM ()
buttonActivate :: actionM ()
buttonContent  :: Bool -> Rect -> renderM ()
```

In Roc they are all expressed with the same effectful arrow:

```roc
request_focus! : state => state
activate! : state => state
content! : ContentDescription => Frame(result, state, event)

ContentDescription : {
    focused : Bool,
    hovered : Bool,
    placement : Placement,
}
```

Thus `content!` is honestly effectful in Puri's immediate, finally-tagless
design; making it pure would require it to build a later rendering
representation or merely move the effectful boundary into a returned widget.
What Roc cannot express is the useful distinction between the application's
`actionM` effects and the renderer's `renderM` effects. Both appear as `=>` and
ultimately share the platform-selected ambient effect vocabulary. The named
content record also avoids an unrelated interface hazard: passing `focused`
and `hovered` as adjacent booleans would make their order invisible at call
sites.

Rendering exposes the same tradeoff. In Haskell, the canvas can abstract over a
carrier such as `m : Type -> Type`:

```haskell
class Monad m => Canvas m paint where
    fillRect :: Rect -> paint -> m ()
```

The same abstraction can support immediate effects, a writer-like recording
interpreter, stateful interpreters, or operations whose later work depends on
values produced by earlier operations. Constraints such as `Monad m` or
`Monoid result` can be named and reused independently of the concrete carrier.

Roc can parameterize over ordinary types and pass records of functions, but not
over a type constructor such as `m`. Puri therefore uses this narrower
encoding:

```roc
Canvas(result, paint) : {
    fill_rect! : Rect, paint => result,
    # ...
}
```

Each operation returns an interpreter-specific `result`. A frame combines
those results using Roc's conventional `default` and `plus` methods:

```roc
where [result.default : result, result.plus : result, result -> result]
```

For RocRay, `result` is effectively `{}` because drawing happens immediately.
For tests, it can be a command fragment that is combined with the fragments
from other operations. This is honest finally-tagless code and is sufficient
for drawing commands whose useful return value is always unit-like.

It is not equivalent to abstracting over `m a`:

- there is no way to express one reusable `Monad`-like constraint over an
  arbitrary carrier;
- `result` cannot vary with the value produced by an operation;
- sequencing in which a later operation depends on an earlier result requires
  explicit accumulator threading, callbacks, or a concrete effect encoding;
  and
- the structural `default`/`plus` constraint must be repeated at API
  boundaries because Roc cannot name the higher-level abstraction we mean.

Roc's preferred tools—effectful functions, structural constraints, and
capability passing—cover many individual cases. Puri is a useful test of how
well they scale when a library wants to abstract over a whole family of effect
interpreters. The current monoidal render-result encoding should remain
visible rather than being hidden behind a retained command tree: it both serves
Puri's present needs and demonstrates exactly where higher-kinded
abstraction would simplify the design.

### Groups of method constraints cannot be named

**Category:** language expressiveness and API readability

Generic geometry functions need several operations on the scalar type. For
example, rectangle intersection currently repeats:

```roc
where [
    a.plus : a, a -> a,
    a.minus : a, a -> a,
    a.is_lt : a, a -> Bool,
    a.is_gt : a, a -> Bool,
]
```

The same issue appears in Puri and Roclay with the repeated monoidal
render-result constraint:

```roc
where [
    result.default : result,
    result.plus : result, result -> result,
]
```

There is currently no supported way to give either group a reusable name.
Roc's current
[type documentation](https://github.com/roc-lang/roc/blob/main/docs/langref/types.md#where-clauses)
only describes listing individual method requirements directly on each
annotation.

Notably, the new compiler's
[`WhereClause` parser representation](https://github.com/roc-lang/roc/blob/main/src/parse/AST.zig)
still contains an alias form designed for exactly this purpose:

```roc
Sort(a) : a where [a.order : a, a -> Ordering]

sort : List(elem) -> List(elem) where [elem.Sort]
```

However, the checker deliberately reports this as an
[`Unsupported Where Clause`](https://github.com/roc-lang/roc/blob/main/src/check/report.zig#L2008-L2036),
explaining that this syntax belonged to abilities, which have been removed
from Roc. The parser support is therefore not usable language functionality.

The available alternatives all have significant costs:

1. Repeat the structural method constraints on every relevant annotation.
2. Choose a concrete or nominal scalar such as `F32`, eliminating the generic
   parameter but locking the geometry library to that number type.
3. Define an explicit dictionary record such as `NumericOps(a)` containing the
   functions and pass it as a value to every operation. This factors the list,
   but adds an argument throughout the API and gives up normal operator/static
   method syntax inside the implementation.

The standalone geometry package takes the first option. This preserves generic
geometry and keeps call sites free of explicit operation dictionaries, but it
is noisy, easy for nominally equivalent APIs to drift, and exposes the absence
of a basic constraint-alias facility.

Puri itself makes a different prototype tradeoff: it fixes layout, input,
rendering, and text coordinates to `F32`. A final design should allow an
integration to select its natural scalar and carry that type consistently
through placements, events, canvas operations, and text measurements. Doing
that in this port would add a scalar parameter to nearly every public type and
repeat sizeable arithmetic constraints throughout the standard widgets.
Because both Roclay and the current native backend naturally use `F32`, that
verbosity would obscure the event and rendering abstractions without
exercising the polymorphism in the demo. The concrete scalar is therefore
intentional here, not an assertion that backend-independent Puri fundamentally
requires `F32`.
The package centralizes this prototype choice in `puri.Geometry.Scalar` and
defines its point, size, rectangle, inset, and placement aliases from that one
transparent type. This prevents the fixed choice from drifting between APIs;
it does not make changing the scalar sufficient to generalize the library.

The canvas makes the propagation cost particularly easy to see. Generalizing
only its capability record would be straightforward:

```roc
Operations(result, paint, scalar) : {
    fill_rect! : Geometry2d.Rect(scalar), paint => result,
    stroke_line! : Geometry2d.Point(scalar), Geometry2d.Point(scalar), paint, scalar => result,
    # ...
}
```

But it would not yet let an integration select a scalar: widgets receive their
geometry from `Frame.Placement`, compare pointer coordinates from `Event`, use
widths and baselines from `TextMeasurement`, and perform arithmetic in button,
line-edit, and scrolling code. A coherent generic API would therefore also
need types along these lines:

```roc
Frame(result, state, event, scalar)
Widget(result, state, event, scalar)
PointerButtonEvent(scalar)
Metrics(scalar)
Description(state, paint, scalar)
```

The scalar parameter and its required arithmetic and ordering methods would
then flow through most widget annotations. Since Roc cannot name that group of
constraints, this is not one extra parameter at the canvas boundary; it is
repeated public-API machinery across the library. Keeping the prototype
consistently `F32` is less misleading than making `Canvas` superficially
generic while every useful caller still fixes it to `F32`.

### Compiler derivation is a closed set

**Category:** language-design tradeoff and missing extensibility

The Zig compiler can synthesize six recognized methods:

- `is_eq`
- `to_hash`
- `parser_for`
- `encoder_for`
- `map`
- `map!`

Anonymous records, tuples, and tag unions receive supported structural
derivations automatically. A nominal type opts into one by declaring the
method with `_` as its annotation:

```roc
Point := { x : F32, y : F32 }.{
    is_eq : _
    to_hash : _
}
```

This is useful, but unlike Haskell's deriving mechanisms it is not extensible
by libraries. In particular, Roc cannot derive `plus`, `default`, ordering, or
an arbitrary project-defined method by recursively using the corresponding
methods of a type's components.

`Frame` makes the missing case concrete. Its combination is simply the
fieldwise combination of its placement result and handler:

```roc
plus = |earlier, later| {
    placement_result: earlier.placement_result + later.placement_result,
    handler: earlier.handler + later.handler,
}
```

`Handler` contains a function, so structural equality cannot be derived for a
`Frame`; functions do not support equality. That does not prevent a plausible
structural `plus`, however: `Handler` explicitly defines `plus`, and the
placement-result constraint supplies the other field's `plus`. If Roc
supported library-extensible derivation, those are exactly the component
operations needed to synthesize `Frame.plus`. Today the implementation must be
written manually because `plus` is outside the compiler's closed list, not
because one of `Frame`'s fields lacks the operation.

### Default values use zero-argument functions

**Category:** language-design convention and open question

Roc's standard `default` protocol represents an identity value as a
zero-argument function:

```roc
default : () -> U8
default = || 0
```

Generic code such as `List.sum` consequently calls `Item.default()`. Puri
follows that convention for its composable types:

```roc
Handler.default()
Frame.default()
```

Calling the constrained method also requires a local capitalized type alias:

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

`PlacementResult` has no runtime meaning; it is a transparent local alias for
the lowercase type variable. It exists because static method syntax requires a
capitalized type name in expression position, so
`placement_result.default()` cannot express the same call. Roc's own
`List.sum` uses the corresponding `Item : item` alias. This is minor
boilerplate, but it makes a generic operation less direct precisely where its
type annotation has already identified the constrained type.

For these immutable values a constant could express the same semantics more
directly:

```roc
default : Handler(state, event)
```

However, that would have a different structural method type and would no
longer satisfy generic code written for the standard function-shaped
`default`. Supporting both shapes would either split the convention or require
additional language machinery that treats a value and a zero-argument
function uniformly.

The runtime cost should normally disappear when the compiler inlines a trivial
pure `default()` call, so this is principally an API/readability question. It
is still worth asking why the ecosystem chose the function form universally:
whether it enables important defaults that must construct fresh values, and
whether relying on optimization for the common constant case has any practical
cost in development or unoptimized builds.

## Resolved compiler bugs encountered here

### Optimized builds changed layout behavior

An optimized build placed a trailing Todo button off-screen while the
development build produced the correct layout. Reduction showed that
SpecConstr added a phantom argument to a zero-argument root after
loop-carried reassignment:

- [`roc-lang/roc#10317`](https://github.com/roc-lang/roc/issues/10317)
- fixed by
  [`roc-lang/roc#10336`](https://github.com/roc-lang/roc/pull/10336)

The bug reproduced on native ARM64, x86-64 under Rosetta, and the WASM
compiler path. The standalone reducer was removed from this workspace after
the fix landed and a newer nightly was adopted.
