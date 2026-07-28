# Why Puri?

Puri begins with a practical question: can we define the behavior of controls
such as text editors, buttons, and scroll views once, without also choosing who
owns their state?

UI libraries have made layout engines and rendering backends modular before.
State management is usually less replaceable. A component is commonly born
retained, immediate, or React-style, and using it with another model means
rewriting or wrapping much of its behavior. Puri instead makes a component's
current inputs and possible state transitions explicit while retaining nothing
itself. The layer above Puri decides how those inputs persist.

## Honest complexity

Puri is not optimized to make the smallest UI take the fewest lines of code.
A framework that chooses one state model, renderer, and layout engine can offer
a much shorter path through its happy cases. Puri is instead trying to state
the actual problem precisely, so that a complex UI is no more complicated than
the problem itself requires and does not accumulate hidden synchronization
costs.

That does not rule out convenient higher-level APIs. A retained widget tree, an
immediate-mode identity store, or a React-style reconciler could all be built
against Puri. Each could make different state-management tradeoffs while
sharing the same stateless widget behavior, layout adapters, and rendering
backends. The low-level interface is explicit so that convenience can be added
in layers rather than baked into every widget.

## The two-state problem

Most interactive applications have two parallel collections of durable state:

1. **Application state** describes the domain: documents, tasks, accounts,
   selections meaningful to the application, and so on.
2. **UI state** describes the interaction with one presentation: keyboard
   focus, text carets and selections, open menus, scroll offsets, drag state,
   and similar details.

A pure view function appears to provide a simple architecture:

```text
view : ApplicationModel -> UiDescription
```

The actual running UI nevertheless has its own state. A retained framework
stores it in widget objects. An immediate framework commonly stores it in a
table and reconnects calls using explicit IDs, hashes, or call position. A
React-style framework reconciles successive descriptions with a retained
component tree, while the browser continues to own such state as focus, text
selection, and scrolling.

## Identity is history, not output

> Stable identity is not a property of an output value. It is a relationship
> between occurrences in different evaluations of a function.

Given only `view(old_model)` and `view(new_model)`, a framework sees two values
and their structure. It does not necessarily see the history connecting their
elements. Consider two evaluations with identical visible endpoints:

```text
old: [Row("A"), Row("B")]
new: [Row("A"), Row("B")]
```

Perhaps nothing changed. Perhaps both rows were deleted and replaced by
visually identical new rows. Preserving focus and text selection is sensible
in the first history and potentially wrong in the second. No algorithm that
sees only those snapshots can distinguish the histories.

Every inferred identity strategy adds assumptions:

- position treats insertion, reordering, and some conditional output as
  identity changes;
- content hashes fail when content changes or equal values occur more than
  once;
- structural paths make otherwise harmless wrapping and refactoring affect
  identity; and
- explicit keys work only when a layer already knows the intended lifecycle
  and threads it through the output.

Explicit keys are often the right local answer, but they are not free metadata.
They move lifecycle semantics into the input model and component API.
Presentation-only nodes need identities that may not exist in the domain, and
child identity is commonly scoped beneath parent identity, so changing one
ancestor can reset a whole subtree.

Snapshot reconciliation is therefore trying to reconstruct provenance that
the pure function's result did not contain. The same old and new values can be
connected by an update, move, replacement, or deletion-plus-insertion, each
with a different intended effect on associated UI state.

## The simple answer: keep one state

The Todo example uses the least elaborate solution: UI state is ordinary data
in the same model as application state. Its focus, line-edit selections, and
scroll offset pass through Puri descriptions and handlers just like task
labels do.

For example, an application could choose to keep per-task presentation state
directly beside its domain data:

```roc
TaskUi : {
    editing : Bool,
    selection : LineEditing.SelectionState,
}

Task : {
    id : U64,
    title : Str,
    completed : Bool,
    ui : TaskUi,
}
```

Puri does not require this particular organization. The UI fields could instead
live in a keyed table, a retained object, or an incremental runtime. The point
is that their ownership and lifetime are explicit rather than hidden inside
the widget implementation.

This can be mundane and still valuable. If a list item needs presentation
state, store that state beside the item or in a keyed field of the model. If
the domain model must be serialized independently, define one projection that
removes UI fields and another that supplies defaults when loading. Or serialize
the UI fields as well and restore the application where the user left it.

There is no second state store to reconnect, so there is no synchronization
problem and no identity required by Puri. This is only one way to use Puri: a
retained layer, immediate ID store, or reconciler can instead own the same
explicit values and construct the same descriptions.

## Continuations avoid output identity

There is a smaller version of the identity problem inside a single layout
pass. A traditional layout API accepts descriptions, computes geometry, and
returns a detached collection of rectangles or render commands. If
widget-specific rendering and event behavior happen elsewhere, the caller
needs some identity, index, or stored payload with which to associate each
output with the code that produced its input.

Clay's render commands carry both an element ID and opaque user data. A direct
binding could encode Puri work into that output and interpret it after layout,
but that would introduce an initial command representation and a correlation
step into Puri's otherwise finally-tagless interface.

Roclay changes this part of Clay's architecture. Each leaf, decorator, text
line, or controlled container carries a placement continuation:

```roc
Place(output) : Placement => output
```

Once layout is solved, Roclay calls the continuation attached to that exact
node. The continuation can draw immediately, construct the handler for the
settled geometry, and return an interpreter-specific result. Results compose
in placement order. There is no detached Puri output to identify and later
match back to a widget.

These are two related eliminations of identity:

- explicit state means Puri itself need not reconnect a widget to hidden state
  from a previous frame; and
- placement continuations mean it need not reconnect a layout result to
  widget behavior later in the current frame.

A state-management layer built above Puri may still choose identities—for
example, an immediate-style keyed store—but those identities belong to that
layer rather than to Puri's component or layout interface.

## The incremental direction

Nothing above requires incremental computation. Keeping one explicit state and
rerunning the UI function is already a complete and useful model. Explicit UI
state also creates a foundation on which a more incremental model can be
studied, however.

The deeper motivation draws on the
[Incremental Lambda Calculus](https://inc-lc.github.io/) (ILC). Given a pure
function `f`, an input `a`, and a change `da`, ILC derives a function that
computes the corresponding output change without recomputing `f` from scratch:

```text
f(a + da) = f(a) + derive(f, a, da)
```

Applied to UI, start with the pure view function:

```text
view : ApplicationModel -> UiDescription
```

A user event can produce either kind of change:

- a local UI change, such as moving a caret or scrolling; or
- an application-model change, such as editing a task or receiving new data.

A local UI change can be applied directly to the current UI state. An
application change can pass through the derivative of `view` to produce a
change to the UI description:

```text
delta_application
    -> derive(view)
    -> delta_description
```

Those derived changes and local UI changes form two parallel streams that must
be merged into the live UI. ILC provides a theory of changes and derivatives;
it does not by itself specify this UI-specific merge, event precedence, or the
identity policy needed when two separately retained state spaces are being
synchronized. Those are part of the problem an incremental UI architecture
still has to solve.

This delta-oriented view also suggests a different treatment of identity.
Rather than compare two snapshots and guess which output occurrence survived,
the change can distinguish update, move, replacement, and insertion. Different
changes may produce the same final value while carrying different temporal
meaning. A derivative preserves change information that snapshot
reconciliation must attempt to recover after the fact. It does not
automatically solve the UI-specific stream merge or lifecycle policy, but it
puts the missing information in a form those policies can inspect.

Phil Freeman's
[Purview](https://github.com/paf31/purescript-purview) explored an adjacent
idea in PureScript: restrict `model -> view` to incrementalizable functions and
propagate model changes to the DOM using ILC rather than a virtual-DOM diff.
Purview describes itself as an unopinionated toolkit capable of supporting
multiple higher-level APIs. Puri is not a port of Purview, but shares the
interest in putting a reusable, less opinionated layer beneath the familiar UI
architectures.

## What Puri contributes

An incremental UI experiment needs a well-defined UI state and change surface.
Existing frameworks tend to hide parts of that surface inside widget objects,
identity tables, reconcilers, or the DOM. Reimplementing a correct text editor
for every experiment is both expensive and a distraction from the state model
being tested.

Puri makes the control boundary explicit:

- descriptions contain everything a component needs for the current
  placement;
- handlers describe the state transitions offered by that placed component;
- frames compose rendering results and handlers;
- Puri retains neither descriptions, state, nor stable identities; and
- layout and rendering are separate integrations.

The `state` parameter in Puri's Roc handlers is the state chosen by the layer
using Puri. In the Todo it is the whole application model. Another integration
could use a retained tree, a keyed store, or the state of an incremental
runtime. The widget implementation does not change.

Puri does not currently implement automatic differentiation, incremental
reconciliation, or delta-stream merging. Its immediate contribution is a
useful set of state-explicit controls and a complete one-state-model example.
Its research contribution is to make the UI side explicit enough that other
state-management architectures can be investigated without first rewriting
the widgets.
