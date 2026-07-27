## Transient event routing for Puri.
##
## A frame owns one Handler value. The newest handler tries an event first and
## Declined falls through to the earlier handler. The event type is structural:
## widgets can require only the cases they understand while backends add others.
import geometry.Geometry2d

PuriHandler := [].{

	Scalar : F32

	HandleResult(state) : [Handled(state), Declined]
	HandleEvent(state, event) : state, event => HandleResult(state)
	FocusAction(state) : state => state
	FocusTarget(state) : {
		rect : Geometry2d.Rect(Scalar),
		request_focus! : FocusAction(state),
	}
	FocusTraversal(state) : {
		first : [Some(FocusTarget(state)), None],
		last : [Some(FocusTarget(state)), None],
		next : [Some(FocusTarget(state)), None],
		previous : [Some(FocusTarget(state)), None],
		has_focus : Bool,
	}

	Handler(state, event) := {
		handle_event! : HandleEvent(state, event),
		focus : FocusTraversal(state),
	}.{
		default : () -> Handler(state, event)
		default = || {
			handle_event!: |_state, _event| Declined,
			focus: PuriHandler.empty_focus,
		}

		## Later-added handlers win, matching draw and placement order.
		plus : Handler(state, event), Handler(state, event) -> Handler(state, event)
		plus = |earlier, later| {
			handle_event!: PuriHandler.compose_handle(earlier.handle_event!, later.handle_event!),
			focus: PuriHandler.combine_focus(earlier.focus, later.focus),
		}
	}

	empty_focus : FocusTraversal(state)
	empty_focus = { first: None, last: None, next: None, previous: None, has_focus: Bool.False }

	## Compose a new handler in front of an older one. Declined deliberately
	## carries no state: a handler that declines cannot smuggle a state change
	## into the fallback path.
	compose_handle : HandleEvent(state, event), HandleEvent(state, event) -> HandleEvent(state, event)
	compose_handle = |earlier!, later!| |state, event| match later!(state, event) {
		Handled(next) => Handled(next)
		Declined => earlier!(state, event)
	}

	first_some : [Some(value), None], [Some(value), None] -> [Some(value), None]
	first_some = |first, second| match first {
		Some(_) => first
		None => second
	}

	combine_focus : FocusTraversal(state), FocusTraversal(state) -> FocusTraversal(state)
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

	on_event : HandleEvent(state, event) -> Handler(state, event)
	on_event = |handle_event!| { ..Handler.default(), handle_event! }

	map_handle : Handler(state, event), (HandleEvent(state, event) -> HandleEvent(state, event)) -> Handler(state, event)
	map_handle = |handler, transform| { ..handler, handle_event!: transform(handler.handle_event!) }

	map_focus_targets : Handler(state, event), (FocusTarget(state) -> FocusTarget(state)) -> Handler(state, event)
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

	focusable : Bool, Geometry2d.Rect(Scalar), FocusAction(state) -> Handler(state, event)
	focusable = |focused, rect, request_focus!| {
		..Handler.default(),
		focus: {
			first: Some({ rect, request_focus! }),
			last: Some({ rect, request_focus! }),
			next: None,
			previous: None,
			has_focus: focused,
		},
	}

	dispatch! : Handler(state, event), state, event => HandleResult(state)
	dispatch! = |handler, state, event| (handler.handle_event!)(state, event)

	FocusDirection : [Forward, Backward]

	dispatch_focus! : Handler(state, event), state, FocusDirection => HandleResult(state)
	dispatch_focus! = |handler, state, direction| {
		backward = match direction {
			Backward => Bool.True
			Forward => Bool.False
		}
		preferred = if backward {
			handler.focus.previous
		} else {
			handler.focus.next
		}
		fallback = if backward {
			handler.focus.last
		} else {
			handler.focus.first
		}
		match PuriHandler.first_some(preferred, fallback) {
			Some(target) => Handled((target.request_focus!)(state))
			None => Declined
		}
	}
}
