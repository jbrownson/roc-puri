## Transient event routing for Puri.
##
## A frame owns one Handler value. The newest handler tries an event first and
## Declined falls through to the earlier handler. The event type is structural:
## widgets can require only the cases they understand while backends add others.

PuriHandler := [].{

	HandleResult(state) : [Handled(state), Declined]
	HandleEvent(state, event) : state, event => HandleResult(state)

	Handler(state, event) := {
		handle_event! : HandleEvent(state, event),
	}.{
		default : () -> Handler(state, event)
		default = || { handle_event!: |_state, _event| Declined }

		## Later-added handlers win, matching draw and placement order.
		plus : Handler(state, event), Handler(state, event) -> Handler(state, event)
		plus = |earlier, later| { handle_event!: PuriHandler.compose_handle(earlier.handle_event!, later.handle_event!) }
	}

	## Compose a new handler in front of an older one. Declined deliberately
	## carries no state: a handler that declines cannot smuggle a state change
	## into the fallback path.
	compose_handle : HandleEvent(state, event), HandleEvent(state, event) -> HandleEvent(state, event)
	compose_handle = |earlier!, later!| |state, event| match later!(state, event) {
		Handled(next) => Handled(next)
		Declined => earlier!(state, event)
	}

	on_event : HandleEvent(state, event) -> Handler(state, event)
	on_event = |handle_event!| { ..Handler.default(), handle_event! }

	map_handle : Handler(state, event), (HandleEvent(state, event) -> HandleEvent(state, event)) -> Handler(state, event)
	map_handle = |handler, transform| { ..handler, handle_event!: transform(handler.handle_event!) }

	dispatch! : Handler(state, event), state, event => HandleResult(state)
	dispatch! = |handler, state, event| (handler.handle_event!)(state, event)
}
