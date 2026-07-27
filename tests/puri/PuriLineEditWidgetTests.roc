app [main!] {
	test_host: platform "../../test-platform/main.roc",
	geometry: "../../geometry/main.roc",
	roclay: "../../roclay/main.roc",
	puri: "../../puri/main.roc",
	puri_roclay: "../../puri-roclay/main.roc",
	recording: "./support/main.roc",
}

import geometry.Geometry2d
import puri.Puri
import puri.PuriCanvas
import recording.PuriCanvasRecording
import puri.PuriHandler
import puri.PuriLineEdit
import puri.PuriLineEditWidget
import puri.PuriTextMeasurement
import puri_roclay.PuriRoclay
import roclay.Roclay

AppState : {
	clipboard : Str,
	text : Str,
	selection : [Some(PuriLineEdit.LineEditSelection), None],
}

metrics : Str -> PuriTextMeasurement.Metrics
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
canvas = PuriCanvasRecording.canvas

focus! : AppState, PuriLineEdit.LineEditSelection => AppState
focus! = |model, selection| { ..model, selection: Some(selection) }

change! : AppState, Str, PuriLineEdit.LineEditSelection => AppState
change! = |model, text, selection| { ..model, text, selection: Some(selection) }

blur! : AppState => AppState
blur! = |model| { ..model, selection: None }

submit! : AppState => AppState
submit! = |model| { ..model, text: "submitted" }

clipboard : PuriLineEditWidget.Clipboard(AppState)
clipboard = {
	read!: |model| { context: model, text: model.clipboard },
	write!: |model, text| { ..model, clipboard: text },
}

button_at : F32, F32 -> PuriHandler.PointerButtonEvent
button_at = |x, y| {
	position: Geometry2d.point(x, y),
	button: Some(Primary),
	clicks: 1,
	modifiers: PuriHandler.empty_modifiers,
}

button_at_clicks : F32, F32, U8 -> PuriHandler.PointerButtonEvent
button_at_clicks = |x, y, clicks| { ..button_at(x, y), clicks }

command_event : Str -> PuriHandler.KeyEvent
command_event = |character| {
	key: Character(character),
	state: KeyDown,
	modifiers: { ..PuriHandler.empty_modifiers, meta: Bool.True },
}

place! : Roclay.Layout(Puri.Frame(PuriCanvasRecording.Recording(Str), AppState)) => Puri.Frame(PuriCanvasRecording.Recording(Str), AppState)
place! = |layout| {
	measured = Roclay.measure(layout)
	placement = Geometry2d.root_placement(Geometry2d.rect(0, 0, measured.size.width, measured.size.height))
	(measured.place!)(placement)
}

place_at_width! : Roclay.Layout(Puri.Frame(PuriCanvasRecording.Recording(Str), AppState)), F32 => Puri.Frame(PuriCanvasRecording.Recording(Str), AppState)
place_at_width! = |layout, width| {
	measured = Roclay.measure(layout)
	placement = Geometry2d.root_placement(Geometry2d.rect(0, 0, width, measured.size.height))
	(measured.place!)(placement)
}

unfocused_click_focuses_at_measured_caret! : () => Bool
unfocused_click_focuses_at_measured_caret! = || {
	edit = { style, text: "abc", interaction: Unfocused(focus!) }
	layout = PuriRoclay.leaf(PuriLineEditWidget.line_edit!(canvas, measure!, edit))
	measured = Roclay.measure(layout)
	frame = place!(layout)
	model = { clipboard: "", text: "abc", selection: None }
	inside = PuriHandler.dispatch_pointer_down!(frame.handler, model, button_at(6.2, 5))
	outside = PuriHandler.dispatch_pointer_down!(frame.handler, model, button_at(40, 5))
	focused_correctly = match inside {
		Handled(next) => match next.selection {
			Some(selection) => next.text == "abc" and selection.anchor == 2 and selection.focus == 2 and PuriLineEdit.is_dragging(selection)
			None => Bool.False
		}
		Declined => Bool.False
	}
	measured.size == Geometry2d.size(20, 13) and List.len(frame.result.commands) == 1 and focused_correctly and outside == Declined
}

tab_focuses_at_end! : () => Bool
tab_focuses_at_end! = || {
	edit = { style, text: "abc", interaction: Unfocused(focus!) }
	frame = place!(PuriRoclay.leaf(PuriLineEditWidget.line_edit!(canvas, measure!, edit)))
	model = { clipboard: "", text: "abc", selection: None }
	event = { key: Named(Tab), state: KeyDown, modifiers: PuriHandler.empty_modifiers }
	match PuriHandler.dispatch_key!(frame.handler, model, event) {
		Handled(next) => match next.selection {
			Some(selection) => selection.anchor == 3 and selection.focus == 3 and !(PuriLineEdit.is_dragging(selection))
			None => Bool.False
		}
		Declined => Bool.False
	}
}

focused_edit_draws_caret_and_dispatches! : () => Bool
focused_edit_draws_caret_and_dispatches! = || {
	selection = PuriLineEdit.selection_at_end("hi")
	interaction = Focused({ selection, change!, submit!, blur!, clipboard })
	frame = place!(PuriRoclay.leaf(PuriLineEditWidget.line_edit!(canvas, measure!, { style, text: "hi", interaction })))
	model = { clipboard: "", text: "hi", selection: Some(selection) }
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
	draws_text_and_caret = match List.get(frame.result.commands, 0) {
		Ok(Clip(data)) => List.len(data.children) == 2
		_ => Bool.False
	}
	List.len(frame.result.commands) == 1 and draws_text_and_caret and typed_correctly and submitted_correctly and blurred_correctly
}

selection_draws_behind_text_and_caret! : () => Bool
selection_draws_behind_text_and_caret! = || {
	selection = { anchor: 1, focus: 3, drag: NotDragging }
	interaction = Focused({ selection, change!, submit!, blur!, clipboard })
	frame = place!(PuriRoclay.leaf(PuriLineEditWidget.line_edit!(canvas, measure!, { style, text: "abcd", interaction })))
	match List.get(frame.result.commands, 0) {
		Ok(Clip(clip)) => {
			commands = clip.children
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
			clip.rect == Geometry2d.rect(0, 0, 20, 13) and List.len(commands) == 3 and selection_first and text_second and caret_last
		}
		_ => Bool.False
	}
}

overflow_scrolls_to_caret_inside_clip! : () => Bool
overflow_scrolls_to_caret_inside_clip! = || {
	text = "abcdefghij"
	selection = PuriLineEdit.selection_at_end(text)
	interaction = Focused({ selection, change!, submit!, blur!, clipboard })
	layout = PuriRoclay.leaf(PuriLineEditWidget.line_edit!(canvas, measure!, { style, text, interaction }))
	frame = place_at_width!(layout, 10)
	match List.get(frame.result.commands, 0) {
		Ok(Clip(clip)) => {
			text_matches = match List.get(clip.children, 0) {
				Ok(FillText(data)) => data.text == text and data.at == Geometry2d.point(-13.5, 9)
				_ => Bool.False
			}
			caret_matches = match List.get(clip.children, 1) {
				Ok(FillRect(data)) => data.paint == "caret" and data.rect == Geometry2d.rect(6.5, 1, 1.5, 11)
				_ => Bool.False
			}
			clip.rect == Geometry2d.rect(0, 0, 10, 13) and List.len(clip.children) == 2 and text_matches and caret_matches
		}
		_ => Bool.False
	}
}

constrained_parent_shrinks_edit_below_text_width! : () => Bool
constrained_parent_shrinks_edit_below_text_width! = || {
	text = "abcdefghij"
	selection = PuriLineEdit.selection_at_end(text)
	interaction = Focused({ selection, change!, submit!, blur!, clipboard })
	edit = PuriRoclay.leaf(PuriLineEditWidget.line_edit!(canvas, measure!, { style, text, interaction }))
	fill = Roclay.sized(
		{ width: Fill(Roclay.unbounded), height: Fit(Roclay.unbounded) },
		edit,
	)
	container = Roclay.box(
		{ ..Roclay.default_box, sizing: { width: Fixed(22), height: Fixed(13) } },
		[fill],
	)
	frame = place!(container)
	match List.get(frame.result.commands, 0) {
		Ok(Clip(clip)) => {
			text_matches = match List.get(clip.children, 0) {
				Ok(FillText(data)) => data.text == text and data.at == Geometry2d.point(-1.5, 9)
				_ => Bool.False
			}
			caret_matches = match List.get(clip.children, 1) {
				Ok(FillRect(data)) => data.paint == "caret" and data.rect == Geometry2d.rect(18.5, 1, 1.5, 11)
				_ => Bool.False
			}
			clip.rect == Geometry2d.rect(0, 0, 22, 13) and List.len(clip.children) == 2 and text_matches and caret_matches
		}
		_ => Bool.False
	}
}

multiple_clicks_select_word_then_all! : () => Bool
multiple_clicks_select_word_then_all! = || {
	selection = PuriLineEdit.selection_at_end("one two")
	interaction = Focused({ selection, change!, submit!, blur!, clipboard })
	frame = place!(PuriRoclay.leaf(PuriLineEditWidget.line_edit!(canvas, measure!, { style, text: "one two", interaction })))
	model = { clipboard: "", text: "one two", selection: Some(selection) }
	double_clicked = PuriHandler.dispatch_pointer_down!(frame.handler, model, button_at_clicks(12, 5, 2))
	triple_clicked = PuriHandler.dispatch_pointer_down!(frame.handler, model, button_at_clicks(12, 5, 3))
	double_matches = match double_clicked {
		Handled(next) => match next.selection {
			Some(next_selection) => next_selection.anchor == 4 and next_selection.focus == 7
			None => Bool.False
		}
		Declined => Bool.False
	}
	triple_matches = match triple_clicked {
		Handled(next) => match next.selection {
			Some(next_selection) => next_selection.anchor == 0 and next_selection.focus == 7
			None => Bool.False
		}
		Declined => Bool.False
	}
	double_matches and triple_matches
}

clipboard_commands_use_caller_capability! : () => Bool
clipboard_commands_use_caller_capability! = || {
	selection = { anchor: 1, focus: 4, drag: NotDragging }
	interaction = Focused({ selection, change!, submit!, blur!, clipboard })
	frame = place!(PuriRoclay.leaf(PuriLineEditWidget.line_edit!(canvas, measure!, { style, text: "hello", interaction })))
	model = { clipboard: "", text: "hello", selection: Some(selection) }
	copied = PuriHandler.dispatch_key!(frame.handler, model, command_event("c"))
	cut = PuriHandler.dispatch_key!(frame.handler, model, command_event("x"))
	copy_matches = match copied {
		Handled(next) => next.clipboard == "ell" and next.text == "hello"
		Declined => Bool.False
	}
	cut_matches = match cut {
		Handled(next) => match next.selection {
			Some(next_selection) => next.clipboard == "ell" and next.text == "ho" and next_selection.anchor == 1 and next_selection.focus == 1
			None => Bool.False
		}
		Declined => Bool.False
	}

	end_selection = PuriLineEdit.selection_at_end("hi")
	paste_interaction = Focused({ selection: end_selection, change!, submit!, blur!, clipboard })
	paste_frame = place!(PuriRoclay.leaf(PuriLineEditWidget.line_edit!(canvas, measure!, { style, text: "hi", interaction: paste_interaction })))
	pasted = PuriHandler.dispatch_key!(paste_frame.handler, { clipboard: " there", text: "hi", selection: Some(end_selection) }, command_event("v"))
	paste_matches = match pasted {
		Handled(next) => next.text == "hi there" and next.clipboard == " there"
		Declined => Bool.False
	}
	copy_matches and cut_matches and paste_matches
}

main! = || if unfocused_click_focuses_at_measured_caret!() and tab_focuses_at_end!() and focused_edit_draws_caret_and_dispatches!() and selection_draws_behind_text_and_caret!() and overflow_scrolls_to_caret_inside_clip!() and constrained_parent_shrinks_edit_below_text_width!() and multiple_clicks_select_word_then_all!() and clipboard_commands_use_caller_capability!() 0 else 1
