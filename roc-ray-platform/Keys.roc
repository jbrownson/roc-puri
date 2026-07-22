Keys := [].{

	KeyboardKey := [
		Key0,
		Key1,
		Key2,
		Key3,
		Key4,
		Key5,
		Key6,
		Key7,
		Key8,
		Key9,
		KeyA,
		KeyB,
		KeyC,
		KeyD,
		KeyE,
		KeyF,
		KeyG,
		KeyH,
		KeyI,
		KeyJ,
		KeyK,
		KeyL,
		KeyM,
		KeyN,
		KeyO,
		KeyP,
		KeyQ,
		KeyR,
		KeyS,
		KeyT,
		KeyU,
		KeyV,
		KeyW,
		KeyX,
		KeyY,
		KeyZ,
		KeySpace,
		KeyEnter,
		KeyBackspace,
		KeyDelete,
		KeyRight,
		KeyLeft,
		KeyHome,
		KeyEnd,
		KeyLeftShift,
		KeyLeftControl,
		KeyLeftAlt,
		KeyLeftSuper,
		KeyRightShift,
		KeyRightControl,
		KeyRightAlt,
		KeyRightSuper,
	]

	key_code : KeyboardKey -> U64
	key_code = |key| match key {
		KeySpace => 32
		Key0 => 48
		Key1 => 49
		Key2 => 50
		Key3 => 51
		Key4 => 52
		Key5 => 53
		Key6 => 54
		Key7 => 55
		Key8 => 56
		Key9 => 57
		KeyA => 65
		KeyB => 66
		KeyC => 67
		KeyD => 68
		KeyE => 69
		KeyF => 70
		KeyG => 71
		KeyH => 72
		KeyI => 73
		KeyJ => 74
		KeyK => 75
		KeyL => 76
		KeyM => 77
		KeyN => 78
		KeyO => 79
		KeyP => 80
		KeyQ => 81
		KeyR => 82
		KeyS => 83
		KeyT => 84
		KeyU => 85
		KeyV => 86
		KeyW => 87
		KeyX => 88
		KeyY => 89
		KeyZ => 90
		KeyEnter => 257
		KeyBackspace => 259
		KeyDelete => 261
		KeyRight => 262
		KeyLeft => 263
		KeyHome => 268
		KeyEnd => 269
		KeyLeftShift => 340
		KeyLeftControl => 341
		KeyLeftAlt => 342
		KeyLeftSuper => 343
		KeyRightShift => 344
		KeyRightControl => 345
		KeyRightAlt => 346
		KeyRightSuper => 347
	}

	key_state : List(U8), KeyboardKey -> Bool
	key_state = |states, key| match List.get(states, Keys.key_code(key)) {
		Ok(state) => state == 1
		Err(_) => Bool.False
	}

	key_down : List(U8), KeyboardKey -> Bool
	key_down = |states, key| Keys.key_state(states, key)

	key_pressed : List(U8), KeyboardKey -> Bool
	key_pressed = |states, key| Keys.key_state(states, key)
}
