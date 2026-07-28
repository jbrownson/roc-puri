## Optional focus policy over an explicit application-supplied order. It handles
## Tab traversal plus unconsumed Escape and primary-pointer clearing. This widget
## draws nothing, owns no focus state, and infers nothing from the widget tree.
import Frame
import Event
import Handler

KeyboardFocus := [].{

	Entry(state) : {
		focused : Bool,
		focus! : state => state,
	}
	Order(state) : List(Entry(state))
	Clear(state) : state => state
	Description(state) : {
		order : Order(state),
		clear! : Clear(state),
	}
	Events(events) : [PointerDown(Event.PointerButtonEvent), Key(Event.KeyEvent), ..events]

	handler : Description(state) -> Handler(state, Events(events))
	handler = |description| {
		Handler.from_function(
			|state, event| match event {
				Key(key) => match (key.state, key.key) {
					(KeyDown, Named(Tab)) => if key.modifiers.alt or key.modifiers.ctrl or key.modifiers.meta or List.is_empty(description.order) {
						Declined
					} else {
						direction = if key.modifiers.shift Previous else Next
						Handled(move!(description.order, state, direction))
					}
					(KeyDown, Named(Escape)) => Handled((description.clear!)(state))
					_ => Declined
				}
				PointerDown({ button: Some(Primary), .. }) => Handled((description.clear!)(state))
				_ => Declined
			},
		)
	}

	widget : Description(state) -> Frame.Widget(result, state, Events(events))
		where [result.default : result]
	widget = |description| {
		|_placement| Frame.register(KeyboardFocus.handler(description), Frame.default())
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
