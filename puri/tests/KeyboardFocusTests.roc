app [main!] {
	test_host: platform "./platform/main.roc",
	puri: "../main.roc",
}

import puri.Event
import puri.Handler
import puri.KeyboardFocus

tab : Bool -> Event.KeyEvent
tab = |shift| {
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

dispatch! : KeyboardFocus.Order(U8), U8, Event.KeyEvent => Handler.HandleResult(U8)
dispatch! = |entries, state, key| Handler.dispatch!(KeyboardFocus.handler(entries), state, Key(key))

traverses_and_wraps! : () => Bool
traverses_and_wraps! = || {
	dispatch!(order(0), 0, tab(Bool.False)) == Handled(1)
		and dispatch!(order(2), 2, tab(Bool.False)) == Handled(0)
			and dispatch!(order(0), 0, tab(Bool.True)) == Handled(2)
}

starts_at_directional_edge! : () => Bool
starts_at_directional_edge! = || {
	dispatch!(order(255), 255, tab(Bool.False)) == Handled(0)
		and dispatch!(order(255), 255, tab(Bool.True)) == Handled(2)
}

declines_when_inactive! : () => Bool
declines_when_inactive! = || {
	modified = { ..tab(Bool.False), modifiers: { ..Event.empty_modifiers, ctrl: Bool.True } }
	enter = { ..tab(Bool.False), key: Named(Enter) }
	dispatch!([], 0, tab(Bool.False)) == Declined
		and dispatch!(order(0), 0, modified) == Declined
			and dispatch!(order(0), 0, enter) == Declined
}

main! = || if traverses_and_wraps!() and starts_at_directional_edge!() and declines_when_inactive!() 0 else 1
