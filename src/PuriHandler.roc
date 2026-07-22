## Transient, composed event handlers for Puri.
##
## A frame owns one Handler value. Each channel is a function, not a region
## list: the newest handler tries first and Declined falls through. Application
## state is supplied at dispatch time, so callbacks never close over mutable
## model state and Puri retains nothing between frames.
import Geometry2d

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

	ImeSelection : {
		start : U64,
		end : U64,
	}

	ImeEvent := [
		ImeEnabled,
		ImeDisabled,
		ImePreedit({ text : Str, selection : [Some(ImeSelection), None] }),
		ImeCommit(Str),
	]

	DispatchResult(context) : [Handled(context), Declined]
	Dispatch(context, event) : context, event => DispatchResult(context)
	FocusAction(context) : context => context
	FocusTraversal(context) : {
		first : [Some(FocusAction(context)), None],
		last : [Some(FocusAction(context)), None],
		next : [Some(FocusAction(context)), None],
		previous : [Some(FocusAction(context)), None],
		has_focus : Bool,
	}

	Handler(context) : {
		pointer_down! : Dispatch(context, PointerButtonEvent),
		pointer_move! : Dispatch(context, PointerUpdate),
		pointer_up! : Dispatch(context, PointerButtonEvent),
		scroll! : Dispatch(context, PointerScrollEvent),
		key! : Dispatch(context, KeyEvent),
		ime! : Dispatch(context, ImeEvent),
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
		ime!: |_context, _event| Declined,
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
		ime!: PuriHandler.compose_dispatch(earlier.ime!, later.ime!),
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

	on_ime : Dispatch(context, ImeEvent) -> Handler(context)
	on_ime = |dispatch!| { ..PuriHandler.empty, ime!: dispatch! }

	focusable : Bool, FocusAction(context) -> Handler(context)
	focusable = |focused, request_focus!| {
		..PuriHandler.empty,
		focus: {
			first: Some(request_focus!),
			last: Some(request_focus!),
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
				Some(request_focus!) => Handled(request_focus!(context))
				None => Declined
			}
		}
		_ => (handler.key!)(context, event)
	}

	dispatch_ime! : Handler(context), context, ImeEvent => DispatchResult(context)
	dispatch_ime! = |handler, context, event| (handler.ime!)(context, event)

	has_modifier : Modifiers -> Bool
	has_modifier = |modifiers| modifiers.shift or modifiers.alt or modifiers.ctrl or modifiers.meta
}
