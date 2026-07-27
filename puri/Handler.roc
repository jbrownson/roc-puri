## Transient event routing for a Puri frame.
##
## A frame owns one Handler value. The newest handler tries an event first and
## Declined falls through to the earlier handler. The event type is structural:
## widgets can require only the cases they understand while backends add others.

Handler(state, event) := (state, event => [Handled(state), Declined]).{
	HandleResult(state) : [Handled(state), Declined]
	HandleEvent(state, event) : state, event => HandleResult(state)

	from_function : HandleEvent(state, event) -> Handler(state, event)
	from_function = |handle_event!| Handler.(handle_event!)

	default : () -> Handler(state, event)
	default = || Handler.(|_state, _event| Declined)

	## Later-added handlers win, matching draw and placement order.
	plus : Handler(state, event), Handler(state, event) -> Handler(state, event)
	plus = |Handler.(earlier!), Handler.(later!)| {
		Handler.(
			|state, event| {
				match later!(state, event) {
					Handled(next) => Handled(next)
					# A declined handler cannot smuggle a state change into fallback.
					Declined => earlier!(state, event)
				}
			},
		)
	}

	map_handle : Handler(state, event), (HandleEvent(state, event) -> HandleEvent(state, event)) -> Handler(state, event)
	map_handle = |Handler.(handle_event!), transform| Handler.(transform(handle_event!))

	dispatch! : Handler(state, event), state, event => HandleResult(state)
	dispatch! = |Handler.(handle_event!), state, event| handle_event!(state, event)
}
