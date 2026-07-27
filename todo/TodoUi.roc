## Page-level composition for the todo example. Persistent state and
## transitions live in Todo; reusable controls live in Puri; TodoTheme binds
## them to this demo's RocRay appearance.
import geometry.Geometry2d
import puri.Frame
import puri.Button
import PuriCanvasRocRay
import puri.Event
import puri.LineEditing
import puri.EditableText
import puri_roclay.ScrollView as RoclayScrollView
import Todo
import TodoTaskRow
import TodoTheme
import roclay.Roclay
import rr.Clipboard

Model : Todo.Model

Events(events) : [PointerDown(Event.PointerButtonEvent), PointerMove(Event.PointerUpdate), PointerUp(Event.PointerButtonEvent), Scroll(Event.PointerScrollEvent), Key(Event.KeyEvent), ..events]

Ui(events) : Roclay.Layout(Frame(TodoTheme.RenderResult, Model, Events(events)))

TodoUi := [].{
	background : TodoTheme.Paint
	background = TodoTheme.background

	ui! : Model, F32, F32, Geometry2d.Point(F32) => Ui(events)
	ui! = |model, width, height, pointer_position| page!(model, width, height, pointer_position)
}

focus! : Model, LineEditing.SelectionState => Model
focus! = |model, selection| Todo.focus_draft(model, selection)

change! : Model, Str, LineEditing.SelectionState => Model
change! = |model, draft, selection| Todo.change_draft(model, draft, selection)

submit! : Model => Model
submit! = |model| Todo.submit_draft(model)

blur! : Model => Model
blur! = |model| Todo.clear_focus(model)

clipboard : EditableText.Clipboard(Model)
clipboard = {
	read!: |model| { state: model, text: Clipboard.get_text!() },
	write!: |model, text| {
		Clipboard.set_text!(text)
		model
	},
}

draft_interaction : Model -> EditableText.Interaction(Model)
draft_interaction = |model| match model.focus {
	DraftFocus(selection) => Focused({ selection, change!, submit!, blur!, clipboard })
	_ => Unfocused(focus!)
}

entry_row! : Model, Geometry2d.Point(F32) => Ui(events)
entry_row! = |model, pointer_position| {
	field = Roclay.fill_width(
		TodoTheme.line_edit!({
			style: TodoTheme.editable_text_style,
			text: model.draft,
			interaction: draft_interaction(model),
		}),
	)

	request_add! : Button.Action(Model)
	request_add! = |state| Todo.focus_add(state)
	add! : Button.Action(Model)
	add! = |state| {
		next = Todo.submit_draft(state)
		Todo.focus_draft(next, LineEditing.selection_at_end(next.draft))
	}
	add_button = TodoTheme.text_button!({
		style: TodoTheme.text_button_style(TodoTheme.accent),
		text: "Add",
		focused: Todo.add_focused(model),
		pointer_position: Some(pointer_position),
		request_focus!: request_add!,
		activate!: add!,
	})

	Roclay.box(
		{
			..Roclay.default_box,
			gap: 12,
			cross_align: CrossCenter,
			sizing: { width: Fill(Roclay.unbounded), height: Fit(Roclay.unbounded) },
		},
		[field, add_button],
	)
}

task_list! : Model, Geometry2d.Point(F32) => Ui(events)
task_list! = |model, pointer_position| {
	var $rows = []
	if List.is_empty(model.items) {
		$rows = List.append($rows, TodoTheme.small_text!(TodoTheme.muted_ink, "No tasks yet."))
	} else {
		for item in model.items {
			$rows = List.append(
				$rows,
				TodoTaskRow.row!({ model, item, pointer_position, clipboard }),
			)
		}
	}
	tasks = Roclay.box(
		{
			..Roclay.default_box,
			direction: TopToBottom,
			gap: 12,
			sizing: { width: Fill(Roclay.unbounded), height: Fit(Roclay.unbounded) },
		},
		$rows,
	)
	RoclayScrollView.vertical!(
		PuriCanvasRocRay.with_clip!,
		{
			offset: model.scroll_offset,
			scroll_to_end: model.scroll_to_end,
			set_offset!: |state, offset| Todo.set_scroll_offset(state, offset),
		},
		{
			..Roclay.default_box,
			sizing: { width: Fill(Roclay.unbounded), height: Fill(Roclay.unbounded) },
		},
		tasks,
	)
}

page! : Model, F32, F32, Geometry2d.Point(F32) => Ui(events)
page! = |model, width, height, pointer_position| {
	children = [
		TodoTheme.title_text!(TodoTheme.ink, "Puri todo"),
		TodoTheme.small_text!(TodoTheme.muted_ink, "Type a task, then press Enter or choose Add."),
		entry_row!(model, pointer_position),
		task_list!(model, pointer_position),
	]
	Roclay.box(
		{
			..Roclay.default_box,
			direction: TopToBottom,
			padding: Geometry2d.insets(32, 28, 32, 28),
			gap: 16,
			sizing: { width: Fixed(width), height: Fixed(height) },
		},
		children,
	)
}
