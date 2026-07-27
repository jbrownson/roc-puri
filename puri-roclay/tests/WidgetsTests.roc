app [main!] {
	test_host: platform "./platform/main.roc",
	geometry: "../../geometry/main.roc",
	roclay: "../../roclay/main.roc",
	puri: "../../puri/main.roc",
	puri_roclay: "../main.roc",
	recording: "./support/main.roc",
}

import geometry.Geometry2d
import puri.Canvas
import recording.CanvasRecording
import puri.TextButton
import puri.TextMeasurement
import puri_roclay.Widgets
import roclay.Roclay

metrics : Str -> TextMeasurement.Metrics
metrics = |string| {
	width: U64.to_f32(Str.count_utf8_bytes(string)) * 5,
	actual_ascent: 6,
	actual_descent: 2,
	font_ascent: 7,
	font_descent: 3,
}

measure! : TextMeasurement.Measure
measure! = |string| metrics(string)

canvas : Canvas.Operations(CanvasRecording.Recording(Str), Str)
canvas = CanvasRecording.canvas

text_button_adapter_measures_and_places! : () => Bool
text_button_adapter_measures_and_places! = || {
	style : TextButton.Style(Str)
	style = {
		padding: Geometry2d.insets(2, 3, 2, 3),
		background_paint: "background",
		hover_background_paint: "hover background",
		border_paint: "border",
		hover_border_paint: "hover border",
		focus_border_paint: "focus border",
		border_width: 1,
		focus_border_width: 2,
		text_paint: "text",
	}
	description = {
		style,
		text: "Add",
		focused: Bool.False,
		pointer_position: None,
		request_focus!: |state| state,
		activate!: |state| state,
	}
	layout = Widgets.text_button!(canvas, measure!, description)
	measured = Roclay.measure(layout)
	frame = (measured.place!)(Geometry2d.root_placement(Geometry2d.rect(0, 0, measured.size.width, measured.size.height)))
	measured.size == Geometry2d.size(21, 14) and List.len(frame.placement_result.commands) == 3
}

main! = || if text_button_adapter_measures_and_places!() 0 else 1
