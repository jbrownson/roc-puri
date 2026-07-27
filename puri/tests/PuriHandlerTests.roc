app [main!] {
	test_host: platform "./platform/main.roc",
	geometry: "../../geometry/main.roc",
	puri: "../main.roc",
}

## Effectful tests for composed, transient Puri handlers.
import geometry.Geometry2d
import puri.PuriHandler

down_at : F32, F32 -> PuriHandler.PointerButtonEvent
down_at = |x, y| {
	position: Geometry2d.point(x, y),
	button: Some(Primary),
	clicks: 1,
	modifiers: PuriHandler.empty_modifiers,
}

gated : Geometry2d.Rect(F32), Str -> PuriHandler.Dispatch(List(Str), PuriHandler.PointerButtonEvent)
gated = |rect, label| |log, event| if Geometry2d.contains(rect, event.position) {
	Handled(List.append(log, label))
} else {
	Declined
}

composition! : () => Bool
composition! = || {
	bottom = PuriHandler.on_pointer_down(gated(Geometry2d.rect(0, 0, 100, 100), "bottom"))
	top = PuriHandler.on_pointer_down(gated(Geometry2d.rect(25, 25, 50, 50), "top"))
	declines = PuriHandler.on_pointer_down(|_log, _event| Declined)
	handler = bottom + top + declines
	center = PuriHandler.dispatch_pointer_down!(handler, [], down_at(50, 50))
	edge = PuriHandler.dispatch_pointer_down!(handler, [], down_at(10, 10))
	outside = PuriHandler.dispatch_pointer_down!(handler, [], down_at(200, 200))
	center == Handled(["top"]) and edge == Handled(["bottom"]) and outside == Declined
}

channels! : () => Bool
channels! = || {
	pointer = PuriHandler.on_pointer_down(|log, _event| Handled(List.append(log, "pointer")))
	key = PuriHandler.on_key(
		|log, event| match event.state {
			KeyDown => Handled(List.append(log, "key"))
			KeyUp => Declined
		},
	)
	handler = pointer + key
	key_event = { key: Named(Enter), state: KeyDown, modifiers: PuriHandler.empty_modifiers }
	pointer_result = PuriHandler.dispatch_pointer_down!(handler, [], down_at(1, 1))
	key_result = PuriHandler.dispatch_key!(handler, [], key_event)
	pointer_result == Handled(["pointer"]) and key_result == Handled(["key"])
}

pointer_bounds_do_not_limit_keys! : () => Bool
pointer_bounds_do_not_limit_keys! = || {
	base = {
		pointer = PuriHandler.on_pointer_down(|value, _event| Handled(value + 1))
		key = PuriHandler.on_key(|value, _event| Handled(value + 10))
		pointer + key
	}
	handler = PuriHandler.within_pointer_bounds(Geometry2d.rect(10, 10, 20, 20), base)
	inside = PuriHandler.dispatch_pointer_down!(handler, 0, down_at(15, 15))
	outside = PuriHandler.dispatch_pointer_down!(handler, 0, down_at(5, 5))
	key = PuriHandler.dispatch_key!(handler, 0, { key: Named(Enter), state: KeyDown, modifiers: PuriHandler.empty_modifiers })
	inside == Handled(1) and outside == Declined and key == Handled(10)
}

default_and_plus_obey_handler_laws! : () => Bool
default_and_plus_obey_handler_laws! = || {
	empty : PuriHandler.Handler(U64)
	empty = PuriHandler.Handler.default()
	first = PuriHandler.on_pointer_down(|value, _event| Handled(value + 1))
	second = PuriHandler.on_pointer_down(|value, _event| Handled(value + 10))
	third = PuriHandler.on_pointer_down(|value, _event| Handled(value + 100))
	event = down_at(1, 1)
	left_identity = PuriHandler.dispatch_pointer_down!(empty + first, 0, event)
	right_identity = PuriHandler.dispatch_pointer_down!(first + empty, 0, event)
	left_associated = PuriHandler.dispatch_pointer_down!((first + second) + third, 0, event)
	right_associated = PuriHandler.dispatch_pointer_down!(first + (second + third), 0, event)
	left_identity == Handled(1)
		and right_identity == Handled(1)
			and left_associated == Handled(100)
				and right_associated == Handled(100)
}

FocusState : { focused : Str }

focus_handler : Str -> PuriHandler.Handler(FocusState)
focus_handler = |focused| {
	first = PuriHandler.focusable(focused == "first", Geometry2d.rect(0, 0, 10, 10), |state| { ..state, focused: "first" })
	second = PuriHandler.focusable(focused == "second", Geometry2d.rect(0, 10, 10, 10), |state| { ..state, focused: "second" })
	third = PuriHandler.focusable(focused == "third", Geometry2d.rect(0, 20, 10, 10), |state| { ..state, focused: "third" })
	first + second + third
}

tab : Bool -> PuriHandler.KeyEvent
tab = |shift| {
	key: Named(Tab),
	state: KeyDown,
	modifiers: { ..PuriHandler.empty_modifiers, shift },
}

focus_result_is : PuriHandler.DispatchResult(FocusState), Str -> Bool
focus_result_is = |result, expected| match result {
	Handled(state) => state.focused == expected
	Declined => Bool.False
}

tab_traverses_and_wraps! : () => Bool
tab_traverses_and_wraps! = || {
	initial = { focused: "none" }
	from_none = focus_handler("none")
	from_second = focus_handler("second")
	from_first = focus_handler("first")
	from_third = focus_handler("third")
	forward_from_none = PuriHandler.dispatch_key!(from_none, initial, tab(Bool.False))
	backward_from_none = PuriHandler.dispatch_key!(from_none, initial, tab(Bool.True))
	forward = PuriHandler.dispatch_key!(from_second, initial, tab(Bool.False))
	backward = PuriHandler.dispatch_key!(from_second, initial, tab(Bool.True))
	wrap_forward = PuriHandler.dispatch_key!(from_third, initial, tab(Bool.False))
	wrap_backward = PuriHandler.dispatch_key!(from_first, initial, tab(Bool.True))
	focus_result_is(forward_from_none, "first")
		and focus_result_is(backward_from_none, "third")
			and focus_result_is(forward, "third")
				and focus_result_is(backward, "first")
					and focus_result_is(wrap_forward, "first")
						and focus_result_is(wrap_backward, "third")
}

main! = || if composition!() and channels!() and pointer_bounds_do_not_limit_keys!() and default_and_plus_obey_handler_laws!() and tab_traverses_and_wraps!() 0 else 1
