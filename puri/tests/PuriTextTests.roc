app [main!] {
	test_host: platform "./platform/main.roc",
	geometry: "../../geometry/main.roc",
	puri: "../main.roc",
	recording: "./support/main.roc",
}

import geometry.Geometry2d
import puri.Puri
import puri.PuriCanvas
import recording.PuriCanvasRecording
import puri.PuriText
import puri.PuriTextMeasurement

metrics : Str -> PuriTextMeasurement.Metrics
metrics = |string| {
	width: U64.to_f32(Str.count_utf8_bytes(string)) * 4,
	actual_ascent: 6,
	actual_descent: 2,
	font_ascent: 7,
	font_descent: 3,
}

measure! : PuriText.Measure
measure! = |string| metrics(string)

draws_at_settled_baseline! : () => Bool
draws_at_settled_baseline! = || {
	canvas : PuriCanvas.Canvas(PuriCanvasRecording.Recording(Str), Str)
	canvas = PuriCanvasRecording.canvas
	measured = PuriText.text!(canvas, measure!, { text: "abc", paint: "ink" })
	placement = Geometry2d.root_placement(Geometry2d.rect(5, 11, measured.preferred_size.width, measured.preferred_size.height))
	frame = (measured.widget!)(placement)
	command_matches = match List.get(frame.result.commands, 0) {
		Ok(FillText(data)) => List.len(frame.result.commands) == 1 and data.at == Geometry2d.point(5, 18) and data.paint == "ink" and data.text == "abc"
		_ => Bool.False
	}
	measured.preferred_size == Geometry2d.size(12, 10) and measured.minimum_size == measured.preferred_size and command_matches
}

main! = || if draws_at_settled_baseline!() 0 else 1
