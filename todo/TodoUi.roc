## Page-level composition for the todo example. Persistent state and
## transitions live in Todo; reusable controls live in Puri; TodoTheme binds
## them to this demo's RocRay appearance.
import geometry.Geometry2d
import puri.Frame
import puri.Button
import RocRayCanvas
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

Events(events) : [PointerDown(Event.PointerButtonEvent), PointerMove(Event.PointerMoveEvent), PointerUp(Event.PointerButtonEvent), Scroll(Event.PointerScrollEvent), Key(Event.KeyEvent), ..events]

Ui(events) : Roclay.Layout(Frame(TodoTheme.RenderResult, Model, Events(events)))

TodoUi := [].{
	ui! : Model, F32, F32, Geometry2d.Point(F32) => Ui(events)
	ui! = |model, width, height, pointer_position| page!(model, width, height, pointer_position)
}

focus_draft! : Model, LineEditing.SelectionState => Model
focus_draft! = |model, selection| Todo.focus_draft(model, selection)

change_draft! : Model, Str, LineEditing.SelectionState => Model
change_draft! = |model, draft, selection| Todo.change_draft(model, draft, selection)

submit_draft! : Model => Model
submit_draft! = |model| Todo.submit_draft(model)

blur_draft! : Model => Model
blur_draft! = |model| Todo.clear_focus(model)

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
	DraftFocus(selection) => Focused({ selection, change!: change_draft!, submit!: submit_draft!, blur!: blur_draft!, clipboard })
	_ => Unfocused(focus_draft!)
}

draft_row! : Model, Geometry2d.Point(F32) => Ui(events)
draft_row! = |model, pointer_position| {
	draft_field = Roclay.fill_width(
		TodoTheme.line_edit!({
			style: TodoTheme.line_edit_style,
			text: model.draft,
			interaction: draft_interaction(model),
		}),
	)

	request_add! : Button.Action(Model)
	request_add! = |state| Todo.focus_target(state, AddButton)
	add! : Button.Action(Model)
	add! = |state| {
		next = Todo.submit_draft(state)
		Todo.focus_draft(next, LineEditing.selection_at_end(next.draft))
	}
	add_button = TodoTheme.text_button!({
		style: TodoTheme.text_button_style(TodoTheme.accent),
		text: "Add",
		focused: Todo.target_focused(model, AddButton),
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
		[draft_field, add_button],
	)
}

task_list! : Model, Geometry2d.Point(F32) => Ui(events)
task_list! = |model, pointer_position| {
	var $rows = []
	if List.is_empty(model.tasks) {
		$rows = List.append($rows, TodoTheme.small_text!(TodoTheme.muted_ink, "No tasks yet."))
	} else {
		var $task_index = 0
		for task in model.tasks {
			$rows = List.append(
				$rows,
				TodoTaskRow.row!({ model, task, task_index: $task_index, pointer_position, clipboard }),
			)
			$task_index = $task_index + 1
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
		RocRayCanvas.with_clip!,
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
		draft_row!(model, pointer_position),
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
