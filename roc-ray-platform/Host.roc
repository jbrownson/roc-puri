Host := {
	timestamp_nanos : U64,
	keys : List(U8),
	keys_pressed : List(U8),
	mouse : {
		buttons : List(U8),
		buttons_pressed : List(U8),
		buttons_released : List(U8),
		x : F32,
		y : F32,
	},
}.{
	ScreenSize : { width : I32, height : I32 }

	get_screen_size! : () => ScreenSize
	disable_escape_exit! : () => {}
	set_window_min_size! : I32, I32 => {}
}
