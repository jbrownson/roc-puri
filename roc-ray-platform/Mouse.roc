Mouse := [].{

	MouseButton := [Left, Right, Middle, Side, Extra, Forward, Back]

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

	button_state : List(U8), MouseButton -> Bool
	button_state = |states, button| match List.get(states, Mouse.button_code(button)) {
		Ok(state) => state == 1
		Err(_) => Bool.False
	}

	button_down : { buttons : List(U8), .. }, MouseButton -> Bool
	button_down = |mouse, button| Mouse.button_state(mouse.buttons, button)

	button_pressed : { buttons_pressed : List(U8), .. }, MouseButton -> Bool
	button_pressed = |mouse, button| Mouse.button_state(mouse.buttons_pressed, button)

	button_released : { buttons_released : List(U8), .. }, MouseButton -> Bool
	button_released = |mouse, button| Mouse.button_state(mouse.buttons_released, button)
}
