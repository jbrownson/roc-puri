## RGBA colors passed directly to RocRay/Raylib.
Color := {
	r : U8,
	g : U8,
	b : U8,
	a : U8,
}.{
	rgba : U8, U8, U8, U8 -> Color
	rgba = |r, g, b, a| { r, g, b, a }

	rgb : U8, U8, U8 -> Color
	rgb = |r, g, b| Color.rgba(r, g, b, 255)

	from_hex_rgb : U32 -> Color
	from_hex_rgb = |hex| {
		r = ((hex // 0x10000) % 0x100).to_u8_wrap()
		g = ((hex // 0x100) % 0x100).to_u8_wrap()
		b = (hex % 0x100).to_u8_wrap()
		Color.rgba(r, g, b, 255)
	}

	from_hex_rgba : U32 -> Color
	from_hex_rgba = |hex| {
		r = ((hex // 0x1000000) % 0x100).to_u8_wrap()
		g = ((hex // 0x10000) % 0x100).to_u8_wrap()
		b = ((hex // 0x100) % 0x100).to_u8_wrap()
		a = (hex % 0x100).to_u8_wrap()
		Color.rgba(r, g, b, a)
	}

	white : Color
	white = Color.rgb(255, 255, 255)
}
