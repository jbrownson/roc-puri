## Todo-specific composition for one task. Standard text, button, checkbox,
## line-edit, frame, and layout behavior comes from Puri and Roclay; this module
## owns only the application's edit/toggle/delete policy.
import geometry.Geometry2d
import puri.Frame
import puri.Button
import puri.Interact
import puri.LineEditing
import puri.EditableText
import puri.Drag
import puri.Reorder
import puri_roclay.Layout
import Todo
import TodoTheme
import roclay.Roclay

TodoTaskRow := [].{

	Description(events) : {
		model : Todo.Model,
		task : Todo.Task,
		task_index : Todo.TaskIndex,
		pointer_position : Geometry2d.Point(F32),
		clipboard : EditableText.Clipboard(Todo.Model),
		renderer : TodoTheme.Renderer,
	}

	DragHandle(events) : Roclay.Layout(Frame(TodoTheme.RenderResult, Todo.Model, EditableText.Events(events)))

	row! : Description(events), DragHandle(events) => Roclay.Layout(Frame(TodoTheme.RenderResult, Todo.Model, EditableText.Events(events)))
	row! = |description, drag_handle| build!(description, drag_handle)
}

build! : TodoTaskRow.Description(events), TodoTaskRow.DragHandle(events) => Roclay.Layout(Frame(TodoTheme.RenderResult, Todo.Model, EditableText.Events(events)))
build! = |description, drag_handle| {
	model = description.model
	task = description.task
	task_index = description.task_index
	pointer_position = description.pointer_position
	renderer = description.renderer
	editing = Todo.is_editing(model, task_index)
	control_pointer_position = match model.drag {
		Idle => Some(pointer_position)
		Armed(_) | Dragging(_) => None
	}

	request_toggle! : Button.Action(Todo.Model)
	request_toggle! = |state| Todo.focus_target(state, TaskCheckbox(task_index))
	toggle! : Button.Action(Todo.Model)
	toggle! = |state| match state.focus {
		ControlFocus(TaskCheckbox(focused_index)) => Todo.toggle(state, focused_index)
		_ => state
	}
	checkbox_style = TodoTheme.checkbox_style(if task.completed TodoTheme.muted_ink else TodoTheme.ink)
	checkbox_description = {
		style: { ..checkbox_style, gap: if editing 0 else checkbox_style.gap },
		label: if editing "" else task.label,
		checked: task.completed,
		focused: Todo.target_focused(model, TaskCheckbox(task_index)),
		pointer_position: control_pointer_position,
		request_focus!: request_toggle!,
		toggle!,
	}
	checkbox_base = TodoTheme.checkbox!(renderer, checkbox_description)
	checkbox_layout = if editing {
		checkbox_base
	} else {
		handle_label! : Interact.PlacedPointerAction(Todo.Model)
		handle_label! = |state, placement, pointer| if pointer.clicks == 1 {
			Todo.focus_target(state, TaskCheckbox(task_index))
		} else {
			text_left = placement.rect.x
				+ checkbox_description.style.horizontal_padding
				+ checkbox_description.style.box_size
				+ checkbox_description.style.gap
			selection = EditableText.selection_at_pointer!(
				TodoTheme.measure_body!,
				task.label,
				pointer.position.x - text_left,
				1,
			)
			Todo.start_label_edit(state, task_index, selection, pointer.position)
		}
		label_handler = Interact.on_primary_pointer_down_where(
			|placement, pointer| {
				label_left = placement.rect.x + checkbox_description.style.horizontal_padding + checkbox_description.style.box_size
				pointer.position.x > label_left
			},
			handle_label!,
		)
		Roclay.fill_width(Layout.after(label_handler, checkbox_base))
	}

	request_edit! : Button.Action(Todo.Model)
	request_edit! = |state| Todo.focus_target(state, EditButton(task_index))
	edit! : Button.Action(Todo.Model)
	edit! = |state| if editing {
		# Requesting focus already committed the active editor.
		state
	} else {
		match state.focus {
			ControlFocus(EditButton(focused_index)) => match Todo.task_at(state, focused_index) {
				Some(focused_task) => Todo.start_edit(state, focused_index, LineEditing.selection_at_end(focused_task.label))
				None => state
			}
			_ => state
		}
	}
	edit_button = TodoTheme.text_button!(
		renderer,
		{
			style: TodoTheme.text_button_style(TodoTheme.accent),
			text: if editing "Done" else "Edit",
			focused: Todo.target_focused(model, EditButton(task_index)),
			pointer_position: control_pointer_position,
			request_focus!: request_edit!,
			activate!: edit!,
		},
	)

	request_remove! : Button.Action(Todo.Model)
	request_remove! = |state| Todo.focus_target(state, DeleteButton(task_index))
	remove! : Button.Action(Todo.Model)
	remove! = |state| match state.focus {
		ControlFocus(DeleteButton(focused_index)) => Todo.remove(state, focused_index)
		_ => state
	}
	remove_button = TodoTheme.text_button!(
		renderer,
		{
			style: TodoTheme.text_button_style(TodoTheme.danger),
			text: "Delete",
			focused: Todo.target_focused(model, DeleteButton(task_index)),
			pointer_position: control_pointer_position,
			request_focus!: request_remove!,
			activate!: remove!,
		},
	)

	row_children = if editing {
		focus_label! : EditableText.Focus(Todo.Model)
		focus_label! = |state, selection| Todo.start_edit(state, task_index, selection)
		change_label! : EditableText.Change(Todo.Model)
		change_label! = |state, label, selection| Todo.change_label(state, task_index, label, selection)
		finish_edit! : EditableText.Submit(Todo.Model)
		finish_edit! = |state| Todo.finish_edit(state, task_index)
		cancel_edit! : EditableText.Cancel(Todo.Model)
		cancel_edit! = |state| Todo.cancel_edit(state)
		label_interaction = match model.focus {
			TaskEditFocus(data) => if data.task_index == task_index {
				Focused({ selection: data.selection, change!: change_label!, submit!: finish_edit!, cancel!: cancel_edit!, clipboard: description.clipboard })
			} else {
				Unfocused(focus_label!)
			}
			_ => Unfocused(focus_label!)
		}
		label_description = {
			style: TodoTheme.compact_line_edit_style,
			text: task.label,
			interaction: label_interaction,
		}
		pointer_hysteresis_origin = Todo.edit_pointer_hysteresis_origin(model, task_index)
		label_edit = TodoTheme.line_edit!(renderer, label_description)
		label_edit_layout = Roclay.fill_width(Layout.after(Drag.hysteresis(pointer_hysteresis_origin, 3), label_edit))
		[drag_handle, checkbox_layout, label_edit_layout, edit_button, remove_button]
	} else {
		[drag_handle, checkbox_layout, edit_button, remove_button]
	}

	row_config = {
		..Roclay.default_box,
		gap: 12,
		cross_align: CrossCenter,
		sizing: { width: Fill(Roclay.unbounded), height: Fit(Roclay.unbounded) },
	}
	row = Roclay.box(row_config, row_children)
	Roclay.fill_width(TodoTheme.task_frame!(renderer, row))
}
