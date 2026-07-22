app [main!] { test_host: platform "../test-platform/main.roc" }

import Geometry2d
import Puri
import PuriCanvas
import PuriCanvasRecording
import PuriCheckbox
import PuriHandler
import Roclay

State : { focused : Bool, checked : Bool }

metrics : Str -> PuriCanvas.TextMetrics
metrics = |string| {
	width: U64.to_f32(Str.count_utf8_bytes(string)) * 2,
	actual_ascent: 7,
	actual_descent: 2,
	font_ascent: 8,
	font_descent: 3,
}

measure! : PuriCheckbox.Measure
measure! = |string| metrics(string)

canvas : PuriCanvas.Canvas(PuriCanvasRecording.Recording(Str), Str)
canvas = PuriCanvasRecording.canvas(metrics)

style : PuriCheckbox.Style(Str)
style = {
	box_size: 10,
	gap: 3,
	vertical_padding: 1,
	horizontal_padding: 2,
	border_width: 1,
	mark_width: 2,
	box_paint: "box",
	border_paint: "border",
	mark_paint: "mark",
	text_paint: "text",
	focus_paint: "focus",
}

request_focus! : State => State
request_focus! = |state| { ..state, focused: Bool.True }

toggle! : State => State
toggle! = |state| { ..state, checked: !(state.checked) }

place! : Bool, Bool => Puri.Frame(PuriCanvasRecording.Recording(Str), State)
place! = |checked, focused| {
	checkbox = { style, label: "ok", checked, focused, request_focus!, toggle! }
	layout = PuriCheckbox.checkbox!(canvas, measure!, checkbox)
	measured = Roclay.measure(layout)
	placement = Geometry2d.root_placement(Geometry2d.rect(4, 5, measured.size.width, measured.size.height))
	(measured.place!)(Puri.frame(PuriCanvasRecording.empty), placement)
}

checked_checkbox_draws_directly! : () => Bool
checked_checkbox_draws_directly! = || {
	frame = place!(Bool.True, Bool.True)
	commands = frame.render.commands
	box_matches = match List.get(commands, 0) {
		Ok(FillRect(data)) => data.rect == Geometry2d.rect(6, 6.5, 10, 10) and data.paint == "box"
		_ => Bool.False
	}
	first_mark_matches = match List.get(commands, 2) {
		Ok(StrokeLine(data)) => data.start == Geometry2d.point(8.2, 11.9) and data.end == Geometry2d.point(10.3, 14) and data.paint == "mark" and data.width == 2
		_ => Bool.False
	}
	text_matches = match List.get(commands, 4) {
		Ok(FillText(data)) => data.at == Geometry2d.point(19, 14) and data.text == "ok" and data.paint == "text"
		_ => Bool.False
	}
	focus_matches = match List.get(commands, 5) {
		Ok(StrokeRect(data)) => data.rect == Geometry2d.rect(4, 5, 21, 13) and data.paint == "focus" and data.width == 2
		_ => Bool.False
	}
	List.len(commands) == 6 and box_matches and first_mark_matches and text_matches and focus_matches
}

checkbox_pointer_composes_focus_and_toggle! : () => Bool
checkbox_pointer_composes_focus_and_toggle! = || {
	frame = place!(Bool.False, Bool.False)
	initial = { focused: Bool.False, checked: Bool.False }
	event = {
		position: Geometry2d.point(10, 10),
		button: Some(Primary),
		modifiers: PuriHandler.empty_modifiers,
	}
	match PuriHandler.dispatch_pointer_down!(frame.handler, initial, event) {
		Handled(next) => next.focused and next.checked
		Declined => Bool.False
	}
}

main! = || if checked_checkbox_draws_directly!() and checkbox_pointer_composes_focus_and_toggle!() 0 else 1
