## Narrow, frame-scoped RocRay 0.9 drawing surface used by the Todo backend.
import Color
import DrawHost

Draw := [].{

	## Opaque drawing authority supplied only while the host runs render!.
	Frame :: DrawHost.Frame.{
		from_host : DrawHost.Frame -> Frame
		from_host = |frame| Frame.(frame)
	}

	Font : DrawHost.Font
	Vector2 : DrawHost.Vector2
	TextSize : DrawHost.TextSize

	RectangleRaw : DrawHost.Rectangle
	RectangleLinesRaw : DrawHost.RectangleLines
	LineRaw : DrawHost.Line
	TextRaw : DrawHost.Text
	MeasureText : DrawHost.MeasureText

	default_font : Font
	default_font = DefaultFont

	default_spacing : F32
	default_spacing = 1

	measure_text! : MeasureText => TextSize
	measure_text! = |config| DrawHost.measure_text!(config)

	clear! : Frame, Color => {}
	clear! = |_frame, color| DrawHost.clear!(color)

	line_raw! : Frame, LineRaw => {}
	line_raw! = |_frame, line| DrawHost.line!(line)

	rectangle_raw! : Frame, RectangleRaw => {}
	rectangle_raw! = |_frame, rectangle| DrawHost.rectangle!(rectangle)

	rectangle_lines_raw! : Frame, RectangleLinesRaw => {}
	rectangle_lines_raw! = |_frame, rectangle| DrawHost.rectangle_lines!(rectangle)

	text_raw! : Frame, TextRaw => {}
	text_raw! = |_frame, text| DrawHost.text!(text)

	## Run a drawing continuation under a nested screen-space clip. The public
	## Puri Canvas scope has no error channel, so exhausting RocRay's defensive
	## scope stack is a backend invariant failure.
	with_scissor! : Frame, { x : F32, y : F32, width : F32, height : F32 }, (Frame => result) => result
	with_scissor! = |frame, bounds, draw!| {
		status = DrawHost.begin_scissor!(bounds)
		if status == 0 {
			result = draw!(frame)
			DrawHost.end_scissor!()
			result
		} else {
			crash "RocRay scissor scope limit exceeded"
		}
	}
}
