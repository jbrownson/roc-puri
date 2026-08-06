app [main!] {
	test_host: platform "./platform/main.roc",
	geometry: "https://github.com/jbrownson/roc-puri-geometry/releases/download/0.1.0/8YcrEeY7J3K9khuA2ULAcMZvzAbqPzdT9qKCDX9YvqSP.tar.zst",
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

measure! : TextMeasurement.Measure
measure! = |string| metrics(string)

draws_at_settled_baseline! : () => Bool
draws_at_settled_baseline! = || {
	canvas : Canvas.Operations(CanvasRecording.Recording(Str), Str)
	canvas = CanvasRecording.canvas
	text_metrics = measure!("abc")
	size = Text.size(text_metrics)
	widget! = Text.widget(canvas, text_metrics, { text: "abc", paint: "ink" })
	placement = Geometry2d.root_placement(Geometry2d.rect(5, 11, size.width, size.height))
	frame = widget!(placement)
	command_matches = match List.get(frame.placement_result.commands, 0) {
		Ok(FillText(data)) => List.len(frame.placement_result.commands) == 1 and data.at == Geometry2d.point(5, 18) and data.paint == "ink" and data.text == "abc"
		_ => Bool.False
	}
	size == Geometry2d.size(12, 10) and command_matches
}

fits_with_ellipsis! : () => Bool
fits_with_ellipsis! = || {
	fits = Text.fit_with_ellipsis!(measure!, "abc", 12) == "abc"
	truncates = Text.fit_with_ellipsis!(measure!, "abcdef", 20) == "ab..."
	preserves_utf8 = Text.fit_with_ellipsis!(measure!, "éxyzq", 20) == "é..."
	too_narrow = Text.fit_with_ellipsis!(measure!, "abcdef", 8) == ""
	fits and truncates and preserves_utf8 and too_narrow
}

main! = || if draws_at_settled_baseline!() and fits_with_ellipsis!() 0 else 1
