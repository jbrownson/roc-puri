app [main!] {
	test_host: platform "./platform/main.roc",
	geometry: "https://github.com/jbrownson/roc-puri-geometry/releases/download/0.1.0/8YcrEeY7J3K9khuA2ULAcMZvzAbqPzdT9qKCDX9YvqSP.tar.zst",
	puri: "../package/main.roc",
}

## Effectful tests for generic, composed Puri handlers.
import puri.Handler

handle_ping : Str -> Handler(List(Str), [Ping, ..events])
handle_ping = |label| {
	Handler.from_function(
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
	declines = Handler.from_function(|_log, _event| Declined)
	handler = earlier + later + declines
	Handler.dispatch!(handler, [], Ping) == Handled(["later"])
		and Handler.dispatch!(handler, [], Unrelated) == Declined
}

structural_event_cases_compose! : () => Bool
structural_event_cases_compose! = || {
	click = Handler.from_function(
		|log, event| match event {
			Click({ count, .. }) => if count == 2 {
				Handled(List.append(log, "click"))
			} else {
				Declined
			}
			_ => Declined
		},
	)
	key = Handler.from_function(
		|log, event| match event {
			Key({ name, .. }) => Handled(List.append(log, name))
			_ => Declined
		},
	)
	handler = click + key
	Handler.dispatch!(handler, [], Click({ count: 2, platform_detail: "extra" })) == Handled(["click"])
		and Handler.dispatch!(handler, [], Key({ name: "enter", repeat: Bool.False })) == Handled(["enter"])
			and Handler.dispatch!(handler, [], NukesWereLaunched) == Declined
}

default_and_plus_obey_handler_laws! : () => Bool
default_and_plus_obey_handler_laws! = || {
	empty : Handler(U64, [Ping])
	empty = Handler.default()
	first = Handler.from_function(|value, _event| Handled(value + 1))
	second = Handler.from_function(|value, _event| Handled(value + 10))
	third = Handler.from_function(|value, _event| Handled(value + 100))
	left_identity = Handler.dispatch!(empty + first, 0, Ping)
	right_identity = Handler.dispatch!(first + empty, 0, Ping)
	left_associated = Handler.dispatch!((first + second) + third, 0, Ping)
	right_associated = Handler.dispatch!(first + (second + third), 0, Ping)
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
