app [main!] { test_host: platform "../test-platform/main.roc" }

## Effectful tests for composed, transient Puri handlers.
import Geometry2d
import PuriHandler

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
	handler = PuriHandler.combine(PuriHandler.combine(bottom, top), declines)
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
	handler = PuriHandler.combine(pointer, key)
	key_event = { key: Named(Enter), state: KeyDown, modifiers: PuriHandler.empty_modifiers }
	pointer_result = PuriHandler.dispatch_pointer_down!(handler, [], down_at(1, 1))
	key_result = PuriHandler.dispatch_key!(handler, [], key_event)
	pointer_result == Handled(["pointer"]) and key_result == Handled(["key"])
}

FocusState : { focused : Str }

focus_handler : Str -> PuriHandler.Handler(FocusState)
focus_handler = |focused| {
	first = PuriHandler.focusable(focused == "first", |state| { ..state, focused: "first" })
	second = PuriHandler.focusable(focused == "second", |state| { ..state, focused: "second" })
	third = PuriHandler.focusable(focused == "third", |state| { ..state, focused: "third" })
	PuriHandler.combine(PuriHandler.combine(first, second), third)
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

main! = || if composition!() and channels!() and tab_traverses_and_wraps!() 0 else 1
