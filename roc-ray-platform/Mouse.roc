Mouse := [].{
	State := {
		buttons : List(U8),
		left : Bool,
		middle : Bool,
		right : Bool,
		wheel : F32,
		wheel_x : F32,
		wheel_y : F32,
		delta_x : F32,
		delta_y : F32,
		x : F32,
		y : F32,
	}.{
		button_down : State, MouseButton -> Bool
		button_down = |mouse, button| Mouse.button_down(mouse, button)

		button_pressed : State, MouseButton -> Bool
		button_pressed = |mouse, button| Mouse.button_pressed(mouse, button)

		button_released : State, MouseButton -> Bool
		button_released = |mouse, button| Mouse.button_released(mouse, button)

		scroll_delta : State -> ScrollDelta
		scroll_delta = |mouse| Mouse.scroll_delta(mouse)
	}

	MouseButton := [Left, Right, Middle, Side, Extra, Forward, Back]
	ScrollDelta : { x : F32, y : F32 }

	button_code : MouseButton -> U64
	button_code = |button| match button {
		Left => 0
		Right => 1
		Middle => 2
		Side => 3
		Extra => 4
		Forward => 5
		Back => 6
	}

	button_state : List(U8), MouseButton, U8 -> Bool
	button_state = |states, button, mask| match List.get(states, Mouse.button_code(button)) {
		Ok(state) => U8.bitwise_and(state, mask) != 0
		Err(_) => Bool.False
	}

	button_down : { buttons : List(U8), .. }, MouseButton -> Bool
	button_down = |mouse, button| Mouse.button_state(mouse.buttons, button, 1)

	button_pressed : { buttons : List(U8), .. }, MouseButton -> Bool
	button_pressed = |mouse, button| Mouse.button_state(mouse.buttons, button, 2)

	button_released : { buttons : List(U8), .. }, MouseButton -> Bool
	button_released = |mouse, button| Mouse.button_state(mouse.buttons, button, 4)

	scroll_delta : { wheel_x : F32, wheel_y : F32, .. } -> ScrollDelta
	scroll_delta = |mouse| { x: mouse.wheel_x, y: mouse.wheel_y }

}
