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

	Recording(paint) : {
		commands : List(Command(paint)),
	}

	empty : Recording(paint)
	empty = { commands: [] }

	canvas : PuriCanvas.Canvas(Recording(paint), paint)
	canvas = {
		clear!: |recording, size, paint| { ..recording, commands: List.append(recording.commands, Clear({ size, paint })) },
		fill_rect!: |recording, rect, paint| { ..recording, commands: List.append(recording.commands, FillRect({ rect, paint })) },
		stroke_rect!: |recording, rect, paint, width| { ..recording, commands: List.append(recording.commands, StrokeRect({ rect, paint, width })) },
		fill_text!: |recording, at, paint, text| { ..recording, commands: List.append(recording.commands, FillText({ at, paint, text })) },
		stroke_line!: |recording, start, end, paint, width| { ..recording, commands: List.append(recording.commands, StrokeLine({ start, end, paint, width })) },
		with_clip!: |recording, rect, draw!| {
			inside = draw!({ commands: [] })
			{ ..recording, commands: List.append(recording.commands, Clip({ rect, children: inside.commands })) }
		},
	}
}
