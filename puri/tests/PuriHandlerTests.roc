app [main!] {
	test_host: platform "./platform/main.roc",
	geometry: "../../geometry/main.roc",
	puri: "../main.roc",
}

## Effectful tests for generic, composed Puri handlers.
import geometry.Geometry2d
import puri.PuriHandler

handle_ping : Str -> PuriHandler.Handler(List(Str), [Ping, ..events])
handle_ping = |label| {
	PuriHandler.on_event(
		|log, event| match event {
			Ping => Handled(List.append(log, label))
			_ => Declined
		},
	)
}

composition! : () => Bool
composition! = || {
	earlier = handle_ping("earlier")
	later = handle_ping("later")
	declines = PuriHandler.on_event(|_log, _event| Declined)
	handler = earlier + later + declines
	PuriHandler.dispatch!(handler, [], Ping) == Handled(["later"])
		and PuriHandler.dispatch!(handler, [], Unrelated) == Declined
}

structural_event_cases_compose! : () => Bool
structural_event_cases_compose! = || {
	click = PuriHandler.on_event(
		|log, event| match event {
			Click({ count, .. }) => if count == 2 {
				Handled(List.append(log, "click"))
			} else {
				Declined
			}
			_ => Declined
		},
	)
	key = PuriHandler.on_event(
		|log, event| match event {
			Key({ name, .. }) => Handled(List.append(log, name))
			_ => Declined
		},
	)
	handler = click + key
	PuriHandler.dispatch!(handler, [], Click({ count: 2, platform_detail: "extra" })) == Handled(["click"])
		and PuriHandler.dispatch!(handler, [], Key({ name: "enter", repeat: Bool.False })) == Handled(["enter"])
			and PuriHandler.dispatch!(handler, [], NukesWereLaunched) == Declined
}

default_and_plus_obey_handler_laws! : () => Bool
default_and_plus_obey_handler_laws! = || {
	empty : PuriHandler.Handler(U64, [Ping])
	empty = PuriHandler.Handler.default()
	first = PuriHandler.on_event(|value, _event| Handled(value + 1))
	second = PuriHandler.on_event(|value, _event| Handled(value + 10))
	third = PuriHandler.on_event(|value, _event| Handled(value + 100))
	left_identity = PuriHandler.dispatch!(empty + first, 0, Ping)
	right_identity = PuriHandler.dispatch!(first + empty, 0, Ping)
	left_associated = PuriHandler.dispatch!((first + second) + third, 0, Ping)
	right_associated = PuriHandler.dispatch!(first + (second + third), 0, Ping)
	left_identity == Handled(1)
		and right_identity == Handled(1)
			and left_associated == Handled(100)
				and right_associated == Handled(100)
}

FocusState : { focused : Str }

focus_handler : Str -> PuriHandler.Handler(FocusState, event)
focus_handler = |focused| {
	first = PuriHandler.focusable(focused == "first", Geometry2d.rect(0, 0, 10, 10), |state| { ..state, focused: "first" })
	second = PuriHandler.focusable(focused == "second", Geometry2d.rect(0, 10, 10, 10), |state| { ..state, focused: "second" })
	third = PuriHandler.focusable(focused == "third", Geometry2d.rect(0, 20, 10, 10), |state| { ..state, focused: "third" })
	first + second + third
}

focus_result_is : PuriHandler.HandleResult(FocusState), Str -> Bool
focus_result_is = |result, expected| match result {
	Handled(state) => state.focused == expected
	Declined => Bool.False
}

focus_traverses_and_wraps! : () => Bool
focus_traverses_and_wraps! = || {
	initial = { focused: "none" }
	from_none = focus_handler("none")
	from_second = focus_handler("second")
	from_first = focus_handler("first")
	from_third = focus_handler("third")
	forward_from_none = PuriHandler.dispatch_focus!(from_none, initial, Forward)
	backward_from_none = PuriHandler.dispatch_focus!(from_none, initial, Backward)
	forward = PuriHandler.dispatch_focus!(from_second, initial, Forward)
	backward = PuriHandler.dispatch_focus!(from_second, initial, Backward)
	wrap_forward = PuriHandler.dispatch_focus!(from_third, initial, Forward)
	wrap_backward = PuriHandler.dispatch_focus!(from_first, initial, Backward)
	focus_result_is(forward_from_none, "first")
		and focus_result_is(backward_from_none, "third")
			and focus_result_is(forward, "third")
				and focus_result_is(backward, "first")
					and focus_result_is(wrap_forward, "first")
						and focus_result_is(wrap_backward, "third")
}

main! = || {
	if composition!()
		and structural_event_cases_compose!()
			and default_and_plus_obey_handler_laws!()
				and focus_traverses_and_wraps!() {
		0
	} else {
		1
	}
}
