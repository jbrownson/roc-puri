app [main!] {
	test_host: platform "./platform/main.roc",
	puri: "../package/main.roc",
}

import puri.Event
import puri.Handler
import puri.KeyboardFocus

tab : Bool -> Event.KeyEvent
tab = |shift| {
	timestamp_nanos: 0,
	key: Named(Tab),
	state: KeyDown,
	modifiers: { ..Event.empty_modifiers, shift },
}

order : U8 -> KeyboardFocus.Order(U8)
order = |focused| [
	{ focused: focused == 0, focus!: |_state| 0 },
	{ focused: focused == 1, focus!: |_state| 1 },
	{ focused: focused == 2, focus!: |_state| 2 },
]

description : U8 -> KeyboardFocus.Description(U8)
description = |focused| {
	order: order(focused),
	clear!: |_state| 255,
}

dispatch_key! : KeyboardFocus.Description(U8), U8, Event.KeyEvent => Handler.HandleResult(U8)
dispatch_key! = |focus, state, key| Handler.dispatch!(KeyboardFocus.handler(focus), state, Key(key))

traverses_and_wraps! : () => Bool
traverses_and_wraps! = || {
	dispatch_key!(description(0), 0, tab(Bool.False)) == Handled(1)
		and dispatch_key!(description(2), 2, tab(Bool.False)) == Handled(0)
			and dispatch_key!(description(0), 0, tab(Bool.True)) == Handled(2)
}

starts_at_directional_edge! : () => Bool
starts_at_directional_edge! = || {
	dispatch_key!(description(255), 255, tab(Bool.False)) == Handled(0)
		and dispatch_key!(description(255), 255, tab(Bool.True)) == Handled(2)
}

declines_when_inactive! : () => Bool
declines_when_inactive! = || {
	modified = { ..tab(Bool.False), modifiers: { ..Event.empty_modifiers, ctrl: Bool.True } }
	enter = { ..tab(Bool.False), key: Named(Enter) }
	empty = { order: [], clear!: |_state| 255 }
	dispatch_key!(empty, 0, tab(Bool.False)) == Declined
		and dispatch_key!(description(0), 0, modified) == Declined
			and dispatch_key!(description(0), 0, enter) == Declined
}

clears_unhandled_focus_events! : () => Bool
clears_unhandled_focus_events! = || {
	escape = { ..tab(Bool.False), key: Named(Escape) }
	pointer = {
		timestamp_nanos: 0,
		position: { x: 10, y: 20 },
		button: Some(Primary),
		clicks: 1,
		modifiers: Event.empty_modifiers,
	}
	handler = KeyboardFocus.handler(description(0))
	Handler.dispatch!(handler, 0, Key(escape)) == Handled(255)
		and Handler.dispatch!(handler, 0, PointerDown(pointer)) == Handled(255)
}

main! = || if traverses_and_wraps!() and starts_at_directional_edge!() and declines_when_inactive!() and clears_unhandled_focus_events!() 0 else 1
