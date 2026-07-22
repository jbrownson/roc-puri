## Minimal RocRay drawing surface needed by PuriCanvasRocRay.
import Color

Draw := [].{

	Font : Box(U64)

	Vector2 : { x : F32, y : F32 }

	TextSize : { width : F32, height : F32 }

	RectangleRaw : {
		x : F32,
		y : F32,
		width : F32,
		height : F32,
		color : Color,
	}

	RectangleLinesRaw : {
		x : F32,
		y : F32,
		width : F32,
		height : F32,
		color : Color,
		thickness : F32,
	}

	LineRaw : {
		start : Vector2,
		end : Vector2,
		color : Color,
		thickness : F32,
	}

	TextRaw : {
		pos : Vector2,
		text : Str,
		size : F32,
		spacing : F32,
		color : Color,
		font : U64,
	}

	MeasureText : {
		text : Str,
		size : F32,
		spacing : F32,
		font : Font,
	}

	MeasureTextRaw : {
		text : Str,
		size : F32,
		spacing : F32,
		font : U64,
	}

	begin_frame! : () => {}
	clear! : Color => {}
	end_frame! : () => {}
	line_raw! : LineRaw => {}
	measure_text_raw! : MeasureTextRaw => TextSize
	rectangle_lines_raw! : RectangleLinesRaw => {}
	rectangle_raw! : RectangleRaw => {}
	text_raw! : TextRaw => {}

	default_font : Font
	default_font = Box.box(0)

	default_spacing : F32
	default_spacing = 1

	measure_text! : MeasureText => TextSize
	measure_text! = |config| Draw.measure_text_raw!({
		text: config.text,
		size: config.size,
		spacing: config.spacing,
		font: Box.unbox(config.font),
	})
}
