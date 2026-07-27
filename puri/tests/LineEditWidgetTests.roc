app [main!] {
	test_host: platform "./platform/main.roc",
	geometry: "../../geometry/main.roc",
	puri: "../main.roc",
	recording: "./support/main.roc",
}

import geometry.Geometry2d
import puri.Frame
import puri.Canvas
import puri.Event
import recording.CanvasRecording
import puri.Handler
import puri.LineEdit
import puri.LineEditWidget
import puri.TextMeasurement

AppState : {
	clipboard : Str,
	text : Str,
	selection : [Some(LineEdit.SelectionState), None],
}

Recording : CanvasRecording.Recording(Str)

metrics : Str -> TextMeasurement.Metrics
metrics = |string| {
	width: U64.to_f32(Str.count_utf8_bytes(string)) * 2,
	actual_ascent: 7,
	actual_descent: 2,
	font_ascent: 8,
	font_descent: 3,
}

measure! : LineEditWidget.Measure
measure! = |string| metrics(string)

style : LineEditWidget.Style(Str)
style = {
	vertical_padding: 1,
	horizontal_padding: 2,
	min_width: 20,
	text_paint: "text",
	caret_paint: "caret",
	selection_paint: "selection",
}

canvas : Canvas.Operations(CanvasRecording.Recording(Str), Str)
canvas = CanvasRecording.canvas

focus! : AppState, LineEdit.SelectionState => AppState
focus! = |model, selection| { ..model, selection: Some(selection) }

change! : AppState, Str, LineEdit.SelectionState => AppState
change! = |model, text, selection| { ..model, text, selection: Some(selection) }

blur! : AppState => AppState
blur! = |model| { ..model, selection: None }

submit! : AppState => AppState
submit! = |model| { ..model, text: "submitted" }

clipboard : LineEditWidget.Clipboard(AppState)
clipboard = {
	read!: |model| { state: model, text: model.clipboard },
	write!: |model, text| { ..model, clipboard: text },
}

button_at : F32, F32 -> Event.PointerButtonEvent
button_at = |x, y| {
	position: Geometry2d.point(x, y),
	button: Some(Primary),
	clicks: 1,
	modifiers: Event.empty_modifiers,
}

button_at_clicks : F32, F32, U8 -> Event.PointerButtonEvent
button_at_clicks = |x, y, clicks| { ..button_at(x, y), clicks }

command_event : Str -> Event.KeyEvent
command_event = |character| {
	key: Character(character),
	state: KeyDown,
	modifiers: { ..Event.empty_modifiers, meta: Bool.True },
}

place! : LineEditWidget.Description(AppState, Str) => Frame(Recording, AppState, LineEditWidget.Events(events))
place! = |edit| {
	text_metrics = measure!(edit.text)
	line_metrics = measure!("Mg")
	size = LineEditWidget.preferred_size(edit.style, text_metrics, line_metrics)
	widget! = LineEditWidget.widget!(canvas, measure!, line_metrics, edit)
	placement = Geometry2d.root_placement(Geometry2d.rect(0, 0, size.width, size.height))
	widget!(placement)
}

place_at_width! : LineEditWidget.Description(AppState, Str), F32 => Frame(Recording, AppState, LineEditWidget.Events(events))
place_at_width! = |edit, width| {
	line_metrics = measure!("Mg")
	size = LineEditWidget.minimum_size(edit.style, line_metrics)
	widget! = LineEditWidget.widget!(canvas, measure!, line_metrics, edit)
	placement = Geometry2d.root_placement(Geometry2d.rect(0, 0, width, size.height))
	widget!(placement)
}

unfocused_click_focuses_at_measured_caret! : () => Bool
unfocused_click_focuses_at_measured_caret! = || {
	edit = { style, text: "abc", interaction: Unfocused(focus!) }
	text_metrics = measure!(edit.text)
	line_metrics = measure!("Mg")
	size = LineEditWidget.preferred_size(edit.style, text_metrics, line_metrics)
	frame = place!(edit)
	model = { clipboard: "", text: "abc", selection: None }
	inside = Handler.dispatch!(frame.handler, model, PointerDown(button_at(6.2, 5)))
	outside = Handler.dispatch!(frame.handler, model, PointerDown(button_at(40, 5)))
	focused_correctly = match inside {
		Handled(next) => match next.selection {
			Some(selection) => next.text == "abc" and selection.anchor == 2 and selection.focus == 2 and LineEdit.is_dragging(selection)
			None => Bool.False
		}
		Declined => Bool.False
	}
	size == Geometry2d.size(20, 13) and List.len(frame.placement_result.commands) == 1 and focused_correctly and outside == Declined
}

focused_edit_draws_caret_and_dispatches! : () => Bool
focused_edit_draws_caret_and_dispatches! = || {
	selection = LineEdit.selection_at_end("hi")
	interaction = Focused({ selection, change!, submit!, blur!, clipboard })
	frame = place!({ style, text: "hi", interaction })
	model = { clipboard: "", text: "hi", selection: Some(selection) }
	type_event = { key: Character("!"), state: KeyDown, modifiers: Event.empty_modifiers }
	enter_event = { key: Named(Enter), state: KeyDown, modifiers: Event.empty_modifiers }
	escape_event = { key: Named(Escape), state: KeyDown, modifiers: Event.empty_modifiers }
	typed = Handler.dispatch!(frame.handler, model, Key(type_event))
	submitted = Handler.dispatch!(frame.handler, model, Key(enter_event))
	blurred = Handler.dispatch!(frame.handler, model, Key(escape_event))
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
	draws_text_and_caret = match List.get(frame.placement_result.commands, 0) {
		Ok(Clip(data)) => List.len(data.children) == 2
		_ => Bool.False
	}
	List.len(frame.placement_result.commands) == 1 and draws_text_and_caret and typed_correctly and submitted_correctly and blurred_correctly
}

selection_draws_behind_text_and_caret! : () => Bool
selection_draws_behind_text_and_caret! = || {
	selection = { anchor: 1, focus: 3, drag: NotDragging }
	interaction = Focused({ selection, change!, submit!, blur!, clipboard })
	frame = place!({ style, text: "abcd", interaction })
	match List.get(frame.placement_result.commands, 0) {
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
	selection = LineEdit.selection_at_end(text)
	interaction = Focused({ selection, change!, submit!, blur!, clipboard })
	edit = { style, text, interaction }
	frame = place_at_width!(edit, 10)
	match List.get(frame.placement_result.commands, 0) {
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

settled_width_can_shrink_edit_below_text_width! : () => Bool
settled_width_can_shrink_edit_below_text_width! = || {
	text = "abcdefghij"
	selection = LineEdit.selection_at_end(text)
	interaction = Focused({ selection, change!, submit!, blur!, clipboard })
	edit = { style, text, interaction }
	frame = place_at_width!(edit, 22)
	match List.get(frame.placement_result.commands, 0) {
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
	selection = LineEdit.selection_at_end("one two")
	interaction = Focused({ selection, change!, submit!, blur!, clipboard })
	frame = place!({ style, text: "one two", interaction })
	model = { clipboard: "", text: "one two", selection: Some(selection) }
	double_clicked = Handler.dispatch!(frame.handler, model, PointerDown(button_at_clicks(12, 5, 2)))
	triple_clicked = Handler.dispatch!(frame.handler, model, PointerDown(button_at_clicks(12, 5, 3)))
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
	frame = place!({ style, text: "hello", interaction })
	model = { clipboard: "", text: "hello", selection: Some(selection) }
	copied = Handler.dispatch!(frame.handler, model, Key(command_event("c")))
	cut = Handler.dispatch!(frame.handler, model, Key(command_event("x")))
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

	end_selection = LineEdit.selection_at_end("hi")
	paste_interaction = Focused({ selection: end_selection, change!, submit!, blur!, clipboard })
	paste_frame = place!({ style, text: "hi", interaction: paste_interaction })
	pasted = Handler.dispatch!(paste_frame.handler, { clipboard: " there", text: "hi", selection: Some(end_selection) }, Key(command_event("v")))
	paste_matches = match pasted {
		Handled(next) => next.text == "hi there" and next.clipboard == " there"
		Declined => Bool.False
	}
	copy_matches and cut_matches and paste_matches
}

main! = || if unfocused_click_focuses_at_measured_caret!() and focused_edit_draws_caret_and_dispatches!() and selection_draws_behind_text_and_caret!() and overflow_scrolls_to_caret_inside_clip!() and settled_width_can_shrink_edit_below_text_width!() and multiple_clicks_select_word_then_all!() and clipboard_commands_use_caller_capability!() 0 else 1
