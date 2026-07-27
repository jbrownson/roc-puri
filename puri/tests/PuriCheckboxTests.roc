app [main!] {
	test_host: platform "./platform/main.roc",
	geometry: "../../geometry/main.roc",
	puri: "../main.roc",
	recording: "./support/main.roc",
}

import geometry.Geometry2d
import puri.Puri
import puri.PuriButton
import puri.PuriCanvas
import puri.PuriEvent
import recording.PuriCanvasRecording
import puri.PuriCheckbox
import puri.PuriHandler
import puri.PuriTextMeasurement

State : { focused : Bool, checked : Bool }

metrics : Str -> PuriTextMeasurement.Metrics
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
canvas = PuriCanvasRecording.canvas

style : PuriCheckbox.Style(Str)
style = {
	box_size: 10,
	gap: 3,
	vertical_padding: 1,
	horizontal_padding: 2,
	border_width: 1,
	mark_width: 2,
	box_paint: "box",
	hover_box_paint: "hover box",
	border_paint: "border",
	hover_border_paint: "hover border",
	mark_paint: "mark",
	text_paint: "text",
	focus_paint: "focus",
}

request_focus! : State => State
request_focus! = |state| { ..state, focused: Bool.True }

toggle! : State => State
toggle! = |state| { ..state, checked: !(state.checked) }

place! : Bool, Bool, [Some(Geometry2d.Point(F32)), None] => Puri.Frame(PuriCanvasRecording.Recording(Str), State, PuriButton.Events(events))
place! = |checked, focused, pointer_position| {
	checkbox = { style, label: "ok", checked, focused, pointer_position, request_focus!, toggle! }
	measured = PuriCheckbox.checkbox!(canvas, measure!, checkbox)
	placement = Geometry2d.root_placement(Geometry2d.rect(4, 5, measured.preferred_size.width, measured.preferred_size.height))
	(measured.widget!)(placement)
}

checked_checkbox_draws_directly! : () => Bool
checked_checkbox_draws_directly! = || {
	frame = place!(Bool.True, Bool.True, None)
	commands = frame.result.commands
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
	frame = place!(Bool.False, Bool.False, None)
	initial = { focused: Bool.False, checked: Bool.False }
	event = {
		position: Geometry2d.point(10, 10),
		button: Some(Primary),
		clicks: 1,
		modifiers: PuriEvent.empty_modifiers,
	}
	match PuriHandler.dispatch!(frame.handler, initial, PointerDown(event)) {
		Handled(next) => next.focused and next.checked
		Declined => Bool.False
	}
}

checkbox_truncates_to_settled_width! : () => Bool
checkbox_truncates_to_settled_width! = || {
	checkbox = {
		style,
		label: "alpha beta gamma",
		checked: Bool.False,
		focused: Bool.False,
		pointer_position: None,
		request_focus!,
		toggle!,
	}
	measured = PuriCheckbox.checkbox!(canvas, measure!, checkbox)
	placement = Geometry2d.root_placement(Geometry2d.rect(0, 0, 38, measured.preferred_size.height))
	frame = (measured.widget!)(placement)
	var $label_fits = Bool.False
	for command in frame.result.commands {
		match command {
			FillText(data) => if data.paint == "text" {
				$label_fits = data.text == "alpha b..." and (metrics(data.text)).width <= 21
			}
			_ => {}
		}
	}
	$label_fits
}

hovered_checkbox_uses_hover_paints! : () => Bool
hovered_checkbox_uses_hover_paints! = || {
	frame = place!(Bool.False, Bool.False, Some(Geometry2d.point(10, 10)))
	box_matches = match List.get(frame.result.commands, 0) {
		Ok(FillRect(data)) => data.paint == "hover box"
		_ => Bool.False
	}
	border_matches = match List.get(frame.result.commands, 1) {
		Ok(StrokeRect(data)) => data.paint == "hover border"
		_ => Bool.False
	}
	List.len(frame.result.commands) == 3 and box_matches and border_matches
}

main! = || if !(checked_checkbox_draws_directly!()) {
	1
} else if !(checkbox_pointer_composes_focus_and_toggle!()) {
	2
} else if !(checkbox_truncates_to_settled_width!()) {
	3
} else if !(hovered_checkbox_uses_hover_paints!()) {
	4
} else {
	0
}
