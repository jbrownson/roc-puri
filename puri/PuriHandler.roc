## Transient, composed event handlers for Puri.
##
## A frame owns one Handler value. Each channel is a function, not a region
## list: the newest handler tries first and Declined falls through. Application
## state is supplied at dispatch time, so callbacks never close over mutable
## model state and Puri retains nothing between frames.
import roclay.Geometry2d

PuriHandler := [].{

	Scalar : F32
	Point : Geometry2d.Point(Scalar)

	Modifiers : {
		shift : Bool,
		alt : Bool,
		ctrl : Bool,
		meta : Bool,
	}

	PointerButton := [Primary, Secondary, Middle, Other(U16)]

	PointerButtonEvent : {
		position : Point,
		button : [Some(PointerButton), None],
		clicks : U8,
		modifiers : Modifiers,
	}

	PointerUpdate : {
		position : Point,
		modifiers : Modifiers,
	}

	PointerScrollEvent : {
		position : Point,
		delta : Point,
		modifiers : Modifiers,
	}

	KeyState := [KeyDown, KeyUp]
	NamedKey := [
		ArrowDown,
		ArrowLeft,
		ArrowRight,
		ArrowUp,
		Backspace,
		Delete,
		End,
		Enter,
		Escape,
		Home,
		Space,
		Tab,
	]
	Key := [Character(Str), Named(NamedKey), Physical(U32)]
	KeyEvent : {
		key : Key,
		state : KeyState,
		modifiers : Modifiers,
	}

	DispatchResult(context) : [Handled(context), Declined]
	Dispatch(context, event) : context, event => DispatchResult(context)
	FocusAction(context) : context => context
	FocusTarget(context) : {
		rect : Geometry2d.Rect(Scalar),
		request_focus! : FocusAction(context),
	}
	FocusTraversal(context) : {
		first : [Some(FocusTarget(context)), None],
		last : [Some(FocusTarget(context)), None],
		next : [Some(FocusTarget(context)), None],
		previous : [Some(FocusTarget(context)), None],
		has_focus : Bool,
	}

	Handler(context) : {
		pointer_down! : Dispatch(context, PointerButtonEvent),
		pointer_move! : Dispatch(context, PointerUpdate),
		pointer_up! : Dispatch(context, PointerButtonEvent),
		scroll! : Dispatch(context, PointerScrollEvent),
		key! : Dispatch(context, KeyEvent),
		focus : FocusTraversal(context),
	}

	empty_modifiers : Modifiers
	empty_modifiers = { shift: Bool.False, alt: Bool.False, ctrl: Bool.False, meta: Bool.False }

	empty_focus : FocusTraversal(context)
	empty_focus = { first: None, last: None, next: None, previous: None, has_focus: Bool.False }

	empty : Handler(context)
	empty = {
		pointer_down!: |_context, _event| Declined,
		pointer_move!: |_context, _event| Declined,
		pointer_up!: |_context, _event| Declined,
		scroll!: |_context, _event| Declined,
		key!: |_context, _event| Declined,
		focus: PuriHandler.empty_focus,
	}

	## Compose a new dispatch in front of an older one. Declined deliberately
	## carries no context: a handler that declines cannot smuggle a state change
	## into the fallback path.
	compose_dispatch : Dispatch(context, event), Dispatch(context, event) -> Dispatch(context, event)
	compose_dispatch = |earlier!, later!| |context, event| match later!(context, event) {
		Handled(next) => Handled(next)
		Declined => earlier!(context, event)
	}

	first_some : [Some(value), None], [Some(value), None] -> [Some(value), None]
	first_some = |first, second| match first {
		Some(_) => first
		None => second
	}

	combine_focus : FocusTraversal(context), FocusTraversal(context) -> FocusTraversal(context)
	combine_focus = |earlier, later| {
		next = if earlier.has_focus {
			PuriHandler.first_some(earlier.next, later.first)
		} else if later.has_focus {
			later.next
		} else {
			None
		}
		previous = if later.has_focus {
			PuriHandler.first_some(later.previous, earlier.last)
		} else if earlier.has_focus {
			earlier.previous
		} else {
			None
		}
		{
			first: PuriHandler.first_some(earlier.first, later.first),
			last: PuriHandler.first_some(later.last, earlier.last),
			next,
			previous,
			has_focus: earlier.has_focus or later.has_focus,
		}
	}

	## Later-combined handlers win, matching draw/placement order: a container
	## can register first and its deeper children can register afterward.
	combine : Handler(context), Handler(context) -> Handler(context)
	combine = |earlier, later| {
		pointer_down!: PuriHandler.compose_dispatch(earlier.pointer_down!, later.pointer_down!),
		pointer_move!: PuriHandler.compose_dispatch(earlier.pointer_move!, later.pointer_move!),
		pointer_up!: PuriHandler.compose_dispatch(earlier.pointer_up!, later.pointer_up!),
		scroll!: PuriHandler.compose_dispatch(earlier.scroll!, later.scroll!),
		key!: PuriHandler.compose_dispatch(earlier.key!, later.key!),
		focus: PuriHandler.combine_focus(earlier.focus, later.focus),
	}

	on_pointer_down : Dispatch(context, PointerButtonEvent) -> Handler(context)
	on_pointer_down = |dispatch!| { ..PuriHandler.empty, pointer_down!: dispatch! }

	on_pointer_move : Dispatch(context, PointerUpdate) -> Handler(context)
	on_pointer_move = |dispatch!| { ..PuriHandler.empty, pointer_move!: dispatch! }

	on_pointer_up : Dispatch(context, PointerButtonEvent) -> Handler(context)
	on_pointer_up = |dispatch!| { ..PuriHandler.empty, pointer_up!: dispatch! }

	on_scroll : Dispatch(context, PointerScrollEvent) -> Handler(context)
	on_scroll = |dispatch!| { ..PuriHandler.empty, scroll!: dispatch! }

	on_key : Dispatch(context, KeyEvent) -> Handler(context)
	on_key = |dispatch!| { ..PuriHandler.empty, key!: dispatch! }

	within_pointer_bounds : Geometry2d.Rect(Scalar), Handler(context) -> Handler(context)
	within_pointer_bounds = |rect, handler| {
		pointer_down! = |context, event| if Geometry2d.contains(rect, event.position) (handler.pointer_down!)(context, event) else Declined
		scroll! = |context, event| if Geometry2d.contains(rect, event.position) (handler.scroll!)(context, event) else Declined
		# Moves and releases remain unbounded so a drag that begins inside can
		# complete after the pointer leaves the viewport.
		{ ..handler, pointer_down!, scroll! }
	}

	map_focus_targets : Handler(context), (FocusTarget(context) -> FocusTarget(context)) -> Handler(context)
	map_focus_targets = |handler, transform| {
		map_optional = |target| match target {
			Some(value) => Some(transform(value))
			None => None
		}
		{
			..handler,
			focus: {
				..handler.focus,
				first: map_optional(handler.focus.first),
				last: map_optional(handler.focus.last),
				next: map_optional(handler.focus.next),
				previous: map_optional(handler.focus.previous),
			},
		}
	}

	focusable : Bool, Geometry2d.Rect(Scalar), FocusAction(context) -> Handler(context)
	focusable = |focused, rect, request_focus!| {
		..PuriHandler.empty,
		focus: {
			first: Some({ rect, request_focus! }),
			last: Some({ rect, request_focus! }),
			next: None,
			previous: None,
			has_focus: focused,
		},
	}

	dispatch_pointer_down! : Handler(context), context, PointerButtonEvent => DispatchResult(context)
	dispatch_pointer_down! = |handler, context, event| (handler.pointer_down!)(context, event)

	dispatch_pointer_move! : Handler(context), context, PointerUpdate => DispatchResult(context)
	dispatch_pointer_move! = |handler, context, event| (handler.pointer_move!)(context, event)

	dispatch_pointer_up! : Handler(context), context, PointerButtonEvent => DispatchResult(context)
	dispatch_pointer_up! = |handler, context, event| (handler.pointer_up!)(context, event)

	dispatch_scroll! : Handler(context), context, PointerScrollEvent => DispatchResult(context)
	dispatch_scroll! = |handler, context, event| (handler.scroll!)(context, event)

	dispatch_key! : Handler(context), context, KeyEvent => DispatchResult(context)
	dispatch_key! = |handler, context, event| match (event.state, event.key) {
		(KeyDown, Named(Tab)) => if event.modifiers.alt or event.modifiers.ctrl or event.modifiers.meta {
			(handler.key!)(context, event)
		} else {
			preferred = if event.modifiers.shift {
				handler.focus.previous
			} else {
				handler.focus.next
			}
			fallback = if event.modifiers.shift {
				handler.focus.last
			} else {
				handler.focus.first
			}
			match PuriHandler.first_some(preferred, fallback) {
				Some(target) => Handled((target.request_focus!)(context))
				None => Declined
			}
		}
		_ => (handler.key!)(context, event)
	}

	has_modifier : Modifiers -> Bool
	has_modifier = |modifiers| modifiers.shift or modifiers.alt or modifiers.ctrl or modifiers.meta
}
