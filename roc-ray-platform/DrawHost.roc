## Internal RocRay 0.9 drawing transport. This module is deliberately not
## exposed by the platform; Draw wraps every drawing effect in a frame
## capability.
import Color

DrawHost := [].{

	Frame :: {}.{
		for_host : Frame
		for_host = Frame.({})
	}

	FontResource :: Box(U64)
	Font : [DefaultFont, LoadedFont(FontResource)]

	Vector2 : { x : F32, y : F32 }
	Rectangle : { x : F32, y : F32, width : F32, height : F32, color : Color }
	RectangleLines : { x : F32, y : F32, width : F32, height : F32, color : Color, thickness : F32 }
	Line : { start : Vector2, end : Vector2, color : Color, thickness : F32 }
	Text : { pos : Vector2, text : Str, size : F32, spacing : F32, color : Color, font : Font }
	MeasureText : { text : Str, size : F32, spacing : F32, font : Font }
	TextSize : { width : F32, height : F32 }
	Scissor : { x : F32, y : F32, width : F32, height : F32 }

	clear! : Color => {}
	line! : Line => {}
	measure_text! : MeasureText => TextSize
	rectangle! : Rectangle => {}
	rectangle_lines! : RectangleLines => {}
	text! : Text => {}
	begin_scissor! : Scissor => U8
	end_scissor! : () => {}
}
