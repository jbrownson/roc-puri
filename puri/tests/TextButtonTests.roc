app [main!] {
	test_host: platform "./platform/main.roc",
	geometry: "../../geometry/main.roc",
	puri: "../main.roc",
	recording: "./support/main.roc",
}

import geometry.Geometry2d
import puri.Frame
import puri.Button
import puri.Canvas
import puri.Event
import recording.CanvasRecording
import puri.Handler
import puri.TextButton
import puri.TextMeasurement

State : { focused : Bool, activations : U64 }

PlacementResult(events) : {
	frame : Frame(CanvasRecording.Recording(Str), State, Button.Events(events)),
	size : Geometry2d.Size(F32),
}

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

request_focus! : State => State
request_focus! = |state| { ..state, focused: Bool.True }

activate! : State => State
activate! = |state| { ..state, activations: state.activations + 1 }

place! : Bool, [Some(Geometry2d.Point(F32)), None] => PlacementResult(events)
place! = |focused, pointer_position| {
	description = { style, text: "Add", focused, pointer_position, request_focus!, activate! }
	text_metrics = measure!(description.text)
	size = TextButton.size(description.style, text_metrics)
	widget! = TextButton.widget(canvas, text_metrics, description)
	placement = Geometry2d.root_placement(Geometry2d.rect(5, 7, size.width, size.height))
	{
		frame: widget!(placement),
		size,
	}
}

draws_hovered_text_button! : () => Bool
draws_hovered_text_button! = || {
	result = place!(Bool.False, Some(Geometry2d.point(10, 10)))
	background_matches = match List.get(result.frame.placement_result.commands, 0) {
		Ok(FillRect(data)) => data.rect == Geometry2d.rect(5, 7, 21, 14) and data.paint == "hover background"
		_ => Bool.False
	}
	border_matches = match List.get(result.frame.placement_result.commands, 1) {
		Ok(StrokeRect(data)) => data.rect == Geometry2d.rect(5, 7, 21, 14) and data.paint == "hover border" and data.width == 1
		_ => Bool.False
	}
	text_matches = match List.get(result.frame.placement_result.commands, 2) {
		Ok(FillText(data)) => data.at == Geometry2d.point(8, 16) and data.paint == "text" and data.text == "Add"
		_ => Bool.False
	}
	result.size == Geometry2d.size(21, 14) and List.len(result.frame.placement_result.commands) == 3 and background_matches and border_matches and text_matches
}

focuses_and_activates! : () => Bool
focuses_and_activates! = || {
	frame = (place!(Bool.False, None)).frame
	initial = { focused: Bool.False, activations: 0 }
	event = {
		timestamp_nanos: 0,
		position: Geometry2d.point(10, 10),
		button: Some(Primary),
		clicks: 1,
		modifiers: Event.empty_modifiers,
	}
	match Handler.dispatch!(frame.handler, initial, PointerDown(event)) {
		Handled(next) => next.focused and next.activations == 1
		Declined => Bool.False
	}
}

focused_style_and_keyboard_activation! : () => Bool
focused_style_and_keyboard_activation! = || {
	frame = (place!(Bool.True, None)).frame
	border_matches = match List.get(frame.placement_result.commands, 1) {
		Ok(StrokeRect(data)) => data.paint == "focus border" and data.width == 2
		_ => Bool.False
	}
	event = { timestamp_nanos: 0, key: Named(Enter), state: KeyDown, modifiers: Event.empty_modifiers }
	result = Handler.dispatch!(frame.handler, { focused: Bool.True, activations: 2 }, Key(event))
	activation_matches = match result {
		Handled(next) => next.activations == 3
		Declined => Bool.False
	}
	border_matches and activation_matches
}

main! = || if draws_hovered_text_button!() and focuses_and_activates!() and focused_style_and_keyboard_activation!() 0 else 1
