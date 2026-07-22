app [main!] { test_host: platform "../test-platform/main.roc" }

import Geometry2d
import Puri
import PuriCanvas
import PuriCanvasRecording
import PuriHandler
import PuriLineEdit
import PuriLineEditWidget
import Roclay

AppState : {
	text : Str,
	selection : [Some(PuriLineEdit.LineEditSelection), None],
}

metrics : Str -> PuriCanvas.TextMetrics
metrics = |string| {
	width: U64.to_f32(Str.count_utf8_bytes(string)) * 2,
	actual_ascent: 7,
	actual_descent: 2,
	font_ascent: 8,
	font_descent: 3,
}

measure! : PuriLineEditWidget.Measure
measure! = |string| metrics(string)

style : PuriLineEditWidget.Style(Str)
style = {
	vertical_padding: 1,
	horizontal_padding: 2,
	min_width: 20,
	text_paint: "text",
	caret_paint: "caret",
	selection_paint: "selection",
}

canvas : PuriCanvas.Canvas(PuriCanvasRecording.Recording(Str), Str)
canvas = PuriCanvasRecording.canvas(metrics)

focus! : AppState, PuriLineEdit.LineEditSelection => AppState
focus! = |model, selection| { ..model, selection: Some(selection) }

change! : AppState, Str, PuriLineEdit.LineEditSelection => AppState
change! = |model, text, selection| { ..model, text, selection: Some(selection) }

blur! : AppState => AppState
blur! = |model| { ..model, selection: None }

submit! : AppState => AppState
submit! = |model| { ..model, text: "submitted" }

button_at : F32, F32 -> PuriHandler.PointerButtonEvent
button_at = |x, y| {
	position: Geometry2d.point(x, y),
	button: Some(Primary),
	modifiers: PuriHandler.empty_modifiers,
}

place! : Roclay.Layout(Puri.Frame(PuriCanvasRecording.Recording(Str), AppState)) => Puri.Frame(PuriCanvasRecording.Recording(Str), AppState)
place! = |layout| {
	measured = Roclay.measure(layout)
	placement = Geometry2d.root_placement(Geometry2d.rect(0, 0, measured.size.width, measured.size.height))
	(measured.place!)(Puri.frame(PuriCanvasRecording.empty), placement)
}

unfocused_click_focuses_at_measured_caret! : () => Bool
unfocused_click_focuses_at_measured_caret! = || {
	edit = { style, text: "abc", interaction: Unfocused(focus!) }
	layout = PuriLineEditWidget.line_edit!(canvas, measure!, edit)
	measured = Roclay.measure(layout)
	frame = place!(layout)
	model = { text: "abc", selection: None }
	inside = PuriHandler.dispatch_pointer_down!(frame.handler, model, button_at(6.2, 5))
	outside = PuriHandler.dispatch_pointer_down!(frame.handler, model, button_at(40, 5))
	focused_correctly = match inside {
		Handled(next) => match next.selection {
			Some(selection) => next.text == "abc" and selection.anchor == 2 and selection.focus == 2 and selection.dragging
			None => Bool.False
		}
		Declined => Bool.False
	}
	measured.size == Geometry2d.size(20, 13) and List.len(frame.render.commands) == 1 and focused_correctly and outside == Declined
}

tab_focuses_at_end! : () => Bool
tab_focuses_at_end! = || {
	edit = { style, text: "abc", interaction: Unfocused(focus!) }
	frame = place!(PuriLineEditWidget.line_edit!(canvas, measure!, edit))
	model = { text: "abc", selection: None }
	event = { key: Named(Tab), state: KeyDown, modifiers: PuriHandler.empty_modifiers }
	match PuriHandler.dispatch_key!(frame.handler, model, event) {
		Handled(next) => match next.selection {
			Some(selection) => selection == PuriLineEdit.selection_at_end("abc")
			None => Bool.False
		}
		Declined => Bool.False
	}
}

focused_edit_draws_caret_and_dispatches! : () => Bool
focused_edit_draws_caret_and_dispatches! = || {
	selection = PuriLineEdit.selection_at_end("hi")
	interaction = Focused({ selection, change!, submit!, blur! })
	frame = place!(PuriLineEditWidget.line_edit!(canvas, measure!, { style, text: "hi", interaction }))
	model = { text: "hi", selection: Some(selection) }
	type_event = { key: Character("!"), state: KeyDown, modifiers: PuriHandler.empty_modifiers }
	enter_event = { key: Named(Enter), state: KeyDown, modifiers: PuriHandler.empty_modifiers }
	escape_event = { key: Named(Escape), state: KeyDown, modifiers: PuriHandler.empty_modifiers }
	typed = PuriHandler.dispatch_key!(frame.handler, model, type_event)
	submitted = PuriHandler.dispatch_key!(frame.handler, model, enter_event)
	blurred = PuriHandler.dispatch_key!(frame.handler, model, escape_event)
	typed_correctly = match typed {
		Handled(next_app) => match next_app.selection {
			Some(next_selection) => next_app.text == "hi!" and next_selection.focus == 3
			None => Bool.False
		}
		Declined => Bool.False
	}
	submitted_correctly = match submitted {
		Handled(next_app) => next_app.selection == Some(selection) and next_app.text == "submitted"
		Declined => Bool.False
	}
	blurred_correctly = match blurred {
		Handled(next_app) => next_app.selection == None and next_app.text == "hi"
		Declined => Bool.False
	}
	List.len(frame.render.commands) == 2 and typed_correctly and submitted_correctly and blurred_correctly
}

selection_draws_behind_text_and_caret! : () => Bool
selection_draws_behind_text_and_caret! = || {
	selection = { anchor: 1, focus: 3, dragging: Bool.False }
	interaction = Focused({ selection, change!, submit!, blur! })
	frame = place!(PuriLineEditWidget.line_edit!(canvas, measure!, { style, text: "abcd", interaction }))
	commands = frame.render.commands
	selection_first = match List.get(commands, 0) {
		Ok(FillRect(data)) => data.paint == "selection" and data.rect == Geometry2d.rect(4, 1, 4, 11)
		_ => Bool.False
	}
	text_second = match List.get(commands, 1) {
		Ok(FillText(data)) => data.paint == "text" and data.text == "abcd" and data.at == Geometry2d.point(2, 9)
		_ => Bool.False
	}
	caret_last = match List.get(commands, 2) {
		Ok(FillRect(data)) => data.paint == "caret" and data.rect == Geometry2d.rect(8, 1, 1.5, 11)
		_ => Bool.False
	}
	List.len(commands) == 3 and selection_first and text_second and caret_last
}

main! = || if unfocused_click_focuses_at_measured_caret!() and tab_focuses_at_end!() and focused_edit_draws_caret_and_dispatches!() and selection_draws_behind_text_and_caret!() 0 else 1
