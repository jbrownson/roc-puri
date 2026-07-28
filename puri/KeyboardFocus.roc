## Optional keyboard traversal over an explicit application-supplied order.
## This widget draws nothing, owns no focus state, and infers nothing from the
## surrounding widget tree.
import Frame
import Event
import Handler

KeyboardFocus := [].{

	Entry(state) : {
		focused : Bool,
		focus! : state => state,
	}
	Order(state) : List(Entry(state))
	Events(events) : [Key(Event.KeyEvent), ..events]

	handler : Order(state) -> Handler(state, Events(events))
	handler = |order| {
		Handler.from_function(
			|state, event| match event {
				Key(key) => match (key.state, key.key) {
					(KeyDown, Named(Tab)) => if key.modifiers.alt or key.modifiers.ctrl or key.modifiers.meta or List.is_empty(order) {
						Declined
					} else {
						direction = if key.modifiers.shift Previous else Next
						Handled(move!(order, state, direction))
					}
					_ => Declined
				}
				_ => Declined
			},
		)
	}

	widget : Order(state) -> Frame.Widget(result, state, Events(events))
		where [result.default : result]
	widget = |order| {
		|_placement| Frame.register(KeyboardFocus.handler(order), Frame.default())
	}
}

Direction := [Next, Previous]

move! : KeyboardFocus.Order(state), state, Direction => state
move! = |order, state, direction| {
	last_index = List.len(order) - 1
	current_index = List.find_first_index(order, |entry| entry.focused)
	next_index = match current_index {
		Ok(index) => match direction {
			Next => if index >= last_index 0 else index + 1
			Previous => if index == 0 last_index else index - 1
		}
		Err(_) => match direction {
			Next => 0
			Previous => last_index
		}
	}
	match List.get(order, next_index) {
		Ok(entry) => (entry.focus!)(state)
		Err(_) => state
	}
}
