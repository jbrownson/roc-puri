import Mouse

Host := {
	frame_count : U64,
	timestamp_nanos : U64,
	frame_time : F32,
	screen : { width : I32, height : I32 },
	keys : List(U8),
	text_input : List(U32),
	gamepads : {
		connected : List(U8),
		buttons : List(U8),
		axes : List(F32),
	},
	mouse : Mouse.State,
}.{
	disable_escape_exit! : () => {}
	set_window_min_size! : I32, I32 => {}
}
