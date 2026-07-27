## Recording interpreter for PuriCanvas, used by tests and frame inspection.
## Production backends can perform the same calls directly.
import puri.PuriCanvas

PuriCanvasRecording := [].{

	Command(paint) := [
		Clear({ size : PuriCanvas.Size, paint : paint }),
		FillRect({ rect : PuriCanvas.Rect, paint : paint }),
		StrokeRect({ rect : PuriCanvas.Rect, paint : paint, width : PuriCanvas.Scalar }),
		FillText({ at : PuriCanvas.Point, paint : paint, text : Str }),
		StrokeLine(
			{
				start : PuriCanvas.Point,
				end : PuriCanvas.Point,
				paint : paint,
				width : PuriCanvas.Scalar,
			},
		),
		Clip({ rect : PuriCanvas.Rect, children : List(Command(paint)) }),
	]

	Recording(paint) := {
		commands : List(Command(paint)),
	}.{
		default : () -> Recording(paint)
		default = || { commands: [] }

		plus : Recording(paint), Recording(paint) -> Recording(paint)
		plus = |earlier, later| { commands: List.concat(earlier.commands, later.commands) }
	}

	canvas : PuriCanvas.Canvas(Recording(paint), paint)
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
