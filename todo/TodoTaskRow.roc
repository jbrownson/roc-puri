## Todo-specific composition for one task. Standard text, button, checkbox,
## line-edit, frame, and layout behavior comes from Puri and Roclay; this module
## owns only the application's edit/toggle/delete policy.
import geometry.Geometry2d
import puri.Frame
import puri.Button
import puri.Interact
import puri.LineEdit
import puri.LineEditWidget
import puri_roclay.Layout
import Todo
import TodoTheme
import roclay.Roclay

TodoTaskRow := [].{

	Row : {
		model : Todo.Model,
		item : Todo.Task,
		pointer_position : Geometry2d.Point(F32),
		clipboard : LineEditWidget.Clipboard(Todo.Model),
	}

	row! : Row => Roclay.Layout(Frame(TodoTheme.RenderResult, Todo.Model, LineEditWidget.Events(events)))
	row! = |description| build!(description)
}

build! : TodoTaskRow.Row => Roclay.Layout(Frame(TodoTheme.RenderResult, Todo.Model, LineEditWidget.Events(events)))
build! = |description| {
	model = description.model
	item = description.item
	pointer_position = description.pointer_position
	editing = Todo.is_editing(model, item.id)

	request_toggle! : Button.Action(Todo.Model)
	request_toggle! = |state| Todo.focus_toggle(state, item.id)
	toggle! : Button.Action(Todo.Model)
	toggle! = |state| Todo.toggle(state, item.id)
	checkbox = {
		style: { ..TodoTheme.checkbox_style(if item.completed TodoTheme.muted_ink else TodoTheme.ink), gap: if editing 0 else 11 },
		label: if editing "" else item.label,
		checked: item.completed,
		focused: Todo.toggle_focused(model, item.id),
		pointer_position: Some(pointer_position),
		request_focus!: request_toggle!,
		toggle!,
	}
	checkbox_base = TodoTheme.checkbox!(checkbox)
	checkbox_layout = if editing {
		checkbox_base
	} else {
		start_edit! : Button.Action(Todo.Model)
		start_edit! = |state| {
			# The first press toggled normally. Match that toggle on the second
			# press before entering edit mode, so the pair preserves completion.
			untoggled = Todo.toggle(state, item.id)
			Todo.start_edit(untoggled, item.id, LineEdit.selection_at_end(item.label))
		}
		Roclay.fill_width(Layout.decorate(Interact.double_clickable(start_edit!), checkbox_base))
	}

	request_edit! : Button.Action(Todo.Model)
	request_edit! = |state| Todo.focus_edit(state, item.id)
	edit! : Button.Action(Todo.Model)
	edit! = |state| if editing {
		Todo.finish_edit(state, item.id)
	} else {
		Todo.start_edit(state, item.id, LineEdit.selection_at_end(item.label))
	}
	edit_button = TodoTheme.text_button!({
		style: TodoTheme.text_button_style(TodoTheme.accent),
		text: if editing "Done" else "Edit",
		focused: Todo.edit_focused(model, item.id),
		pointer_position: Some(pointer_position),
		request_focus!: request_edit!,
		activate!: edit!,
	})

	request_remove! : Button.Action(Todo.Model)
	request_remove! = |state| Todo.focus_remove(state, item.id)
	remove! : Button.Action(Todo.Model)
	remove! = |state| Todo.remove(state, item.id)
	remove_button = TodoTheme.text_button!({
		style: TodoTheme.text_button_style(TodoTheme.danger),
		text: "Delete",
		focused: Todo.remove_focused(model, item.id),
		pointer_position: Some(pointer_position),
		request_focus!: request_remove!,
		activate!: remove!,
	})

	row_children = if editing {
		focus_label! : LineEditWidget.Focus(Todo.Model)
		focus_label! = |state, selection| Todo.start_edit(state, item.id, selection)
		change_label! : LineEditWidget.Change(Todo.Model)
		change_label! = |state, label, selection| Todo.change_label(state, item.id, label, selection)
		finish_edit! : LineEditWidget.Submit(Todo.Model)
		finish_edit! = |state| Todo.finish_edit(state, item.id)
		label_interaction = match model.focus {
			TaskEditFocus(data) => if data.id == item.id {
				Focused({ selection: data.selection, change!: change_label!, submit!: finish_edit!, blur!: finish_edit!, clipboard: description.clipboard })
			} else {
				Unfocused(focus_label!)
			}
			_ => Unfocused(focus_label!)
		}
		label_edit = {
			style: { ..TodoTheme.line_edit_style, vertical_padding: 5, min_width: 120 },
			text: item.label,
			interaction: label_interaction,
		}
		label_edit_layout = Roclay.fill_width(TodoTheme.field!(Roclay.fill_width(TodoTheme.line_edit!(label_edit))))
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
	Roclay.fill_width(TodoTheme.task!(row))
}
