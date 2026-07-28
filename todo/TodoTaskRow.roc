## Todo-specific composition for one task. Standard text, button, checkbox,
## line-edit, frame, and layout behavior comes from Puri and Roclay; this module
## owns only the application's edit/toggle/delete policy.
import geometry.Geometry2d
import puri.Frame
import puri.Button
import puri.Interact
import puri.LineEditing
import puri.EditableText
import puri_roclay.Layout
import Todo
import TodoTheme
import roclay.Roclay

TodoTaskRow := [].{

	Description : {
		model : Todo.Model,
		task : Todo.Task,
		pointer_position : Geometry2d.Point(F32),
		clipboard : EditableText.Clipboard(Todo.Model),
	}

	row! : Description => Roclay.Layout(Frame(TodoTheme.RenderResult, Todo.Model, EditableText.Events(events)))
	row! = |description| build!(description)
}

build! : TodoTaskRow.Description => Roclay.Layout(Frame(TodoTheme.RenderResult, Todo.Model, EditableText.Events(events)))
build! = |description| {
	model = description.model
	task = description.task
	pointer_position = description.pointer_position
	editing = Todo.is_editing(model, task.id)

	request_toggle! : Button.Action(Todo.Model)
	request_toggle! = |state| Todo.focus_control(state, ToggleTask(task.id))
	toggle! : Button.Action(Todo.Model)
	toggle! = |state| Todo.toggle(state, task.id)
	checkbox_description = {
		style: { ..TodoTheme.checkbox_style(if task.completed TodoTheme.muted_ink else TodoTheme.ink), gap: if editing 0 else 11 },
		label: if editing "" else task.label,
		checked: task.completed,
		focused: Todo.control_focused(model, ToggleTask(task.id)),
		pointer_position: Some(pointer_position),
		request_focus!: request_toggle!,
		toggle!,
	}
	checkbox_base = TodoTheme.checkbox!(checkbox_description)
	checkbox_layout = if editing {
		checkbox_base
	} else {
		start_edit! : Button.Action(Todo.Model)
		start_edit! = |state| {
			# The first press toggled normally. Match that toggle on the second
			# press before entering edit mode, so the pair preserves completion.
			restored_completion = Todo.toggle(state, task.id)
			Todo.start_edit(restored_completion, task.id, LineEditing.selection_at_end(task.label))
		}
		Roclay.fill_width(Layout.decorate(Interact.double_clickable(start_edit!), checkbox_base))
	}

	request_edit! : Button.Action(Todo.Model)
	request_edit! = |state| Todo.focus_control(state, EditTask(task.id))
	edit! : Button.Action(Todo.Model)
	edit! = |state| if editing {
		Todo.finish_edit(state, task.id)
	} else {
		Todo.start_edit(state, task.id, LineEditing.selection_at_end(task.label))
	}
	edit_button = TodoTheme.text_button!({
		style: TodoTheme.text_button_style(TodoTheme.accent),
		text: if editing "Done" else "Edit",
		focused: Todo.control_focused(model, EditTask(task.id)),
		pointer_position: Some(pointer_position),
		request_focus!: request_edit!,
		activate!: edit!,
	})

	request_remove! : Button.Action(Todo.Model)
	request_remove! = |state| Todo.focus_control(state, RemoveTask(task.id))
	remove! : Button.Action(Todo.Model)
	remove! = |state| Todo.remove(state, task.id)
	remove_button = TodoTheme.text_button!({
		style: TodoTheme.text_button_style(TodoTheme.danger),
		text: "Delete",
		focused: Todo.control_focused(model, RemoveTask(task.id)),
		pointer_position: Some(pointer_position),
		request_focus!: request_remove!,
		activate!: remove!,
	})

	row_children = if editing {
		focus_label! : EditableText.Focus(Todo.Model)
		focus_label! = |state, selection| Todo.start_edit(state, task.id, selection)
		change_label! : EditableText.Change(Todo.Model)
		change_label! = |state, label, selection| Todo.change_label(state, task.id, label, selection)
		finish_edit! : EditableText.Submit(Todo.Model)
		finish_edit! = |state| Todo.finish_edit(state, task.id)
		label_interaction = match model.focus {
			TaskEditFocus(data) => if data.id == task.id {
				Focused({ selection: data.selection, change!: change_label!, submit!: finish_edit!, blur!: finish_edit!, clipboard: description.clipboard })
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
		label_edit_layout = Roclay.fill_width(TodoTheme.line_edit!(label_description))
		[checkbox_layout, label_edit_layout, edit_button, remove_button]
	} else {
		[checkbox_layout, edit_button, remove_button]
	}

	row_config = {
		..Roclay.default_box,
		gap: 12,
		cross_align: CrossCenter,
		sizing: { width: Fill(Roclay.unbounded), height: Fit(Roclay.unbounded) },
	}
	row = Roclay.box(row_config, row_children)
	Roclay.fill_width(TodoTheme.task_frame!(row))
}
