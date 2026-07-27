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
import puri.EditableText
import puri.Event
import puri.Handler
import puri.LineEditing
import puri.TextMeasurement
import puri_roclay.LineEdit as RoclayLineEdit
import recording.CanvasRecording
import roclay.Roclay

AppState : {
	selection : [Some(LineEditing.SelectionState), None],
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

focus! : AppState, LineEditing.SelectionState => AppState
focus! = |state, selection| { ..state, selection: Some(selection) }

button_at : F32, F32 -> Event.PointerButtonEvent
button_at = |x, y| {
	position: Geometry2d.point(x, y),
	button: Some(Primary),
	clicks: 1,
	modifiers: Event.empty_modifiers,
}

line_edit_keeps_padding_compositional_and_interactive! : () => Bool
line_edit_keeps_padding_compositional_and_interactive! = || {
	description = {
		padding: Geometry2d.insets(2, 3, 4, 5),
		decoration: {
			insets: Geometry2d.insets(0, 0, 0, 0),
			background: Some("background"),
			border_paint: "border",
			border_width: 1,
		},
		editable_text: {
			style: {
				text_paint: "text",
				caret_paint: "caret",
				caret_width: 1.5,
				selection_paint: "selection",
			},
			text: "abc",
			interaction: Unfocused(focus!),
		},
	}
	measured = Roclay.measure(RoclayLineEdit.compose!(canvas, measure!, description))
	frame = (measured.place!)(Geometry2d.root_placement(Geometry2d.rect(10, 20, measured.size.width, measured.size.height)))
	initial = { selection: None }
	left = Handler.dispatch!(frame.handler, initial, PointerDown(button_at(12, 25)))
	right = Handler.dispatch!(frame.handler, initial, PointerDown(button_at(32, 25)))
	outside = Handler.dispatch!(frame.handler, initial, PointerDown(button_at(40, 25)))

	left_matches = match left {
		Handled(state) => match state.selection {
			Some(selection) => selection.focus == 0
			None => Bool.False
		}
		Declined => Bool.False
	}
	right_matches = match right {
		Handled(state) => match state.selection {
			Some(selection) => selection.focus == 3
			None => Bool.False
		}
		Declined => Bool.False
	}
	clip_matches = match List.get(frame.placement_result.commands, 2) {
		Ok(Clip(clip)) => clip.rect == Geometry2d.rect(15, 22, 15, 10)
		_ => Bool.False
	}

	measured.size == Geometry2d.size(23, 16) and List.len(frame.placement_result.commands) == 3 and clip_matches and left_matches and right_matches and outside == Declined
}

main! = || if line_edit_keeps_padding_compositional_and_interactive!() 0 else 1
