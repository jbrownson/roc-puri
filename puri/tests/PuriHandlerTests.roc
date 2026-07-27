app [main!] {
	test_host: platform "./platform/main.roc",
	geometry: "../../geometry/main.roc",
	puri: "../main.roc",
}

## Effectful tests for generic, composed Puri handlers.
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

main! = || {
	if composition!()
		and structural_event_cases_compose!()
			and default_and_plus_obey_handler_laws!() {
		0
	} else {
		1
	}
}
