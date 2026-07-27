app [main!] {
	test_host: platform "./platform/main.roc",
	geometry: "../../geometry/main.roc",
	puri: "../main.roc",
	recording: "./support/main.roc",
}

import geometry.Geometry2d
import puri.Frame
import puri.Canvas
import recording.CanvasRecording
import puri.Text
import puri.TextMeasurement

metrics : Str -> TextMeasurement.Metrics
metrics = |string| {
	width: U64.to_f32(Str.count_utf8_bytes(string)) * 4,
	actual_ascent: 6,
	actual_descent: 2,
	font_ascent: 7,
	font_descent: 3,
}

measure! : Text.Measure
measure! = |string| metrics(string)

draws_at_settled_baseline! : () => Bool
draws_at_settled_baseline! = || {
	canvas : Canvas.Operations(CanvasRecording.Recording(Str), Str)
	canvas = CanvasRecording.canvas
	measured = Text.text!(canvas, measure!, { text: "abc", paint: "ink" })
	placement = Geometry2d.root_placement(Geometry2d.rect(5, 11, measured.preferred_size.width, measured.preferred_size.height))
	frame = (measured.widget!)(placement)
	command_matches = match List.get(frame.placement_result.commands, 0) {
		Ok(FillText(data)) => List.len(frame.placement_result.commands) == 1 and data.at == Geometry2d.point(5, 18) and data.paint == "ink" and data.text == "abc"
		_ => Bool.False
	}
	measured.preferred_size == Geometry2d.size(12, 10) and measured.minimum_size == measured.preferred_size and command_matches
}

main! = || if draws_at_settled_baseline!() 0 else 1
