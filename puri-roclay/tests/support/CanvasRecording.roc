## Recording interpreter for integration tests.
import puri.Canvas

CanvasRecording := [].{

	Command(paint) := [
		Clear({ size : Canvas.Size, paint : paint }),
		FillRect({ rect : Canvas.Rect, paint : paint }),
		StrokeRect({ rect : Canvas.Rect, paint : paint, width : Canvas.Scalar }),
		FillText({ at : Canvas.Point, paint : paint, text : Str }),
		StrokeLine(
			{
				start : Canvas.Point,
				end : Canvas.Point,
				paint : paint,
				width : Canvas.Scalar,
			},
		),
		Clip({ rect : Canvas.Rect, children : List(Command(paint)) }),
	]

	Recording(paint) := {
		commands : List(Command(paint)),
	}.{
		default : () -> Recording(paint)
		default = || { commands: [] }

		plus : Recording(paint), Recording(paint) -> Recording(paint)
		plus = |earlier, later| { commands: List.concat(earlier.commands, later.commands) }
	}

	canvas : Canvas.Operations(Recording(paint), paint)
	canvas = {
		clear!: |size, paint| { commands: [Clear({ size, paint })] },
		fill_rect!: |rect, paint| { commands: [FillRect({ rect, paint })] },
		stroke_rect!: |rect, paint, width| { commands: [StrokeRect({ rect, paint, width })] },
		fill_text!: |at, paint, text| { commands: [FillText({ at, paint, text })] },
		stroke_line!: |start, end, paint, width| { commands: [StrokeLine({ start, end, paint, width })] },
		with_clip!: |rect, draw!| {
			inside = draw!()
			{ commands: [Clip({ rect, children: inside.commands })] }
		},
	}
}
