## Page-level composition for the todo example. Persistent state and
## transitions live in Todo; reusable controls live in Puri; TodoTheme binds
## them to this demo's RocRay appearance.
import geometry.Geometry2d
import puri.Frame
import puri.Button
import RocRayCanvas
import puri.Event
import puri.KeyboardFocus
import puri.LineEditing
import puri.EditableText
import puri_roclay.Layout as RoclayLayout
import puri_roclay.ReorderableList
import puri_roclay.ScrollView as RoclayScrollView
import Todo
import TodoFocus
import TodoTaskRow
import TodoTheme
import roclay.Roclay
import rr.Clipboard

Model : Todo.Model

Ui(events) : Roclay.Layout(Frame(TodoTheme.RenderResult, Model, Event.Events(events)))

TaskListView(events) : {
	layout : Ui(events),
	overlay! : Frame.Widget(TodoTheme.RenderResult, Model, Event.Events(events)),
}

TodoUi := [].{
	ui! : Model, F32, F32, Geometry2d.Point(F32), TodoTheme.Renderer => Ui(events)
	ui! = |model, width, height, pointer_position, renderer| page!(model, width, height, pointer_position, renderer)
}

focus_draft! : Model, LineEditing.SelectionState => Model
focus_draft! = |model, selection| Todo.focus_draft(model, selection)

change_draft! : Model, Str, LineEditing.SelectionState => Model
change_draft! = |model, draft, selection| Todo.change_draft(model, draft, selection)

submit_draft! : Model => Model
submit_draft! = |model| Todo.submit_draft(model)

cancel_draft! : Model => Model
cancel_draft! = |model| Todo.clear_focus(model)

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
	DraftFocus(selection) => Focused({ selection, change!: change_draft!, submit!: submit_draft!, cancel!: cancel_draft!, clipboard })
	_ => Unfocused(focus_draft!)
}

draft_row! : Model, Geometry2d.Point(F32), TodoTheme.Renderer => Ui(events)
draft_row! = |model, pointer_position, renderer| {
	draft_field = Roclay.fill_width(
		TodoTheme.line_edit!(
			renderer,
			{
				style: TodoTheme.line_edit_style,
				text: model.draft,
				interaction: draft_interaction(model),
			},
		),
	)

	request_add! : Button.Action(Model)
	request_add! = |state| Todo.focus_target(state, AddButton)
	add! : Button.Action(Model)
	add! = |state| {
		next = Todo.submit_draft(state)
		Todo.focus_draft(next, LineEditing.selection_at_end(next.draft))
	}
	add_button = TodoTheme.text_button!(
		renderer,
		{
			style: TodoTheme.text_button_style(TodoTheme.accent),
			text: "Add",
			focused: Todo.target_focused(model, AddButton),
			pointer_position: Some(pointer_position),
			request_focus!: request_add!,
			activate!: add!,
		},
	)

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

task_list! : Model, Geometry2d.Point(F32), TodoTheme.Renderer => TaskListView(events)
task_list! = |model, pointer_position, renderer| {
	row! = |task, task_index, drag_handle| {
		TodoTaskRow.row!(
			{ model, task, task_index, pointer_position, clipboard, renderer },
			drag_handle,
		)
	}
	reorderable = ReorderableList.build!({
		items: model.tasks,
		drag: model.drag,
		pointer_position,
		empty: TodoTheme.small_text!(renderer, TodoTheme.muted_ink, "No tasks yet."),
		list_config: {
			..Roclay.default_box,
			gap: 12,
			sizing: { width: Fill(Roclay.unbounded), height: Fit(Roclay.unbounded) },
		},
		target_margin: 6,
		handle!: |description| TodoTheme.drag_handle!(renderer, description),
		row!,
		set_drag!: |state, drag| Todo.set_drag(state, drag),
		commit!: |state, source_index, gap_index| Todo.reorder(state, source_index, gap_index),
	})
	layout = RoclayScrollView.vertical!(
		RocRayCanvas.with_clip!,
		{
			position: model.scroll_position,
			set_position!: |state, position| Todo.set_scroll_position(state, position),
		},
		{
			..Roclay.default_box,
			sizing: { width: Fill(Roclay.unbounded), height: Fill(Roclay.unbounded) },
		},
		reorderable.list,
	)
	{ layout, overlay!: reorderable.overlay! }
}

page! : Model, F32, F32, Geometry2d.Point(F32), TodoTheme.Renderer => Ui(events)
page! = |model, width, height, pointer_position, renderer| {
	task_view = task_list!(model, pointer_position, renderer)
	children = [
		TodoTheme.title_text!(renderer, TodoTheme.ink, "Puri todo"),
		TodoTheme.small_text!(renderer, TodoTheme.muted_ink, "Type a task, then press Enter or choose Add."),
		draft_row!(model, pointer_position, renderer),
		task_view.layout,
	]
	page = Roclay.box(
		{
			..Roclay.default_box,
			direction: TopToBottom,
			padding: Geometry2d.insets(32, 28, 32, 28),
			gap: 16,
			sizing: { width: Fixed(width), height: Fixed(height) },
		},
		children,
	)
	with_focus = RoclayLayout.before(
		KeyboardFocus.widget({
			order: TodoFocus.order(model),
			clear!: |state| Todo.clear_focus(state),
		}),
		page,
	)
	RoclayLayout.after(task_view.overlay!, with_focus)
}
