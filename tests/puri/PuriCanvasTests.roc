app [main!] {
	test_host: platform "../../test-platform/main.roc",
	geometry: "../../geometry/main.roc",
	roclay: "../../roclay/main.roc",
	puri: "../../puri/main.roc",
	recording: "./support/main.roc",
}

import geometry.Geometry2d
import puri.PuriCanvas
import recording.PuriCanvasRecording

metrics : Str -> PuriCanvas.TextMetrics
metrics = |string| {
	width: U64.to_f32(Str.count_utf8_bytes(string)) * 2,
	actual_ascent: 7,
	actual_descent: 2,
	font_ascent: 8,
	font_descent: 3,
}

records_nested_clip! : () => Bool
records_nested_clip! = || {
	canvas : PuriCanvas.Canvas(PuriCanvasRecording.Recording(Str), Str)
	canvas = PuriCanvasRecording.canvas(metrics)
	first = PuriCanvas.fill_rect!(canvas, PuriCanvasRecording.empty, Geometry2d.rect(0, 0, 20, 10), "background")
	final = PuriCanvas.with_clip!(
		canvas,
		first,
		Geometry2d.rect(2, 2, 10, 6),
		|inside| {
			with_text = PuriCanvas.fill_text!(canvas, inside, Geometry2d.point(3, 8), "foreground", "abc")
			PuriCanvas.stroke_line!(canvas, with_text, Geometry2d.point(2, 2), Geometry2d.point(12, 8), "line", 1.5)
		},
	)
	first_matches = match List.get(final.commands, 0) {
		Ok(FillRect(data)) => data.rect == Geometry2d.rect(0, 0, 20, 10) and data.paint == "background"
		_ => Bool.False
	}
	clip_matches = match List.get(final.commands, 1) {
		Ok(Clip(data)) => {
			text_matches = match List.get(data.children, 0) {
				Ok(FillText(text)) => text.at == Geometry2d.point(3, 8) and text.paint == "foreground" and text.text == "abc"
				_ => Bool.False
			}
			line_matches = match List.get(data.children, 1) {
				Ok(StrokeLine(line)) => line.start == Geometry2d.point(2, 2) and line.end == Geometry2d.point(12, 8) and line.paint == "line" and line.width == 1.5
				_ => Bool.False
			}
			data.rect == Geometry2d.rect(2, 2, 10, 6) and List.len(data.children) == 2 and text_matches and line_matches
		}
		_ => Bool.False
	}
	List.len(final.commands) == 2 and first_matches and clip_matches
}

measurement_threads_renderer! : () => Bool
measurement_threads_renderer! = || {
	canvas : PuriCanvas.Canvas(PuriCanvasRecording.Recording(Str), Str)
	canvas = PuriCanvasRecording.canvas(metrics)
	result = PuriCanvas.measure_text!(canvas, PuriCanvasRecording.empty, "abcd")
	result.render == PuriCanvasRecording.empty and result.metrics.width == 8 and result.metrics.font_ascent == 8
}

main! = || if records_nested_clip!() and measurement_threads_renderer!() 0 else 1
