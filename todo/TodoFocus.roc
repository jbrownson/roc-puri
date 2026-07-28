## Todo-specific keyboard focus policy.
##
## Puri widgets consume application-supplied focused state but know nothing
## about focus domains or traversal. This module chooses the controls that
## participate in this application's single Tab order.
import puri.KeyboardFocus
import puri.LineEditing
import Todo

TodoFocus := [].{
	order : Todo.Model -> KeyboardFocus.Order(Todo.Model)
	order = |model| focus_order(model)
}

focus_order : Todo.Model -> KeyboardFocus.Order(Todo.Model)
focus_order = |model| {
	var $order = [draft_entry(model), target_entry(model, AddButton)]
	var $task_index = 0
	for _task in model.tasks {
		$order = List.append($order, target_entry(model, TaskCheckbox($task_index)))
		if Todo.is_editing(model, $task_index) {
			$order = List.append($order, task_editor_entry(model, $task_index))
		}
		$order = List.append($order, target_entry(model, EditButton($task_index)))
		$order = List.append($order, target_entry(model, DeleteButton($task_index)))
		$task_index = $task_index + 1
	}
	$order
}

draft_entry : Todo.Model -> KeyboardFocus.Entry(Todo.Model)
draft_entry = |model| {
	focused: match model.focus {
		DraftFocus(_) => Bool.True
		_ => Bool.False
	},
	focus!: |state| Todo.focus_draft(state, LineEditing.selection_at_end(state.draft)),
}

target_entry : Todo.Model, Todo.FocusTarget -> KeyboardFocus.Entry(Todo.Model)
target_entry = |model, target| {
	focused: Todo.target_focused(model, target),
	focus!: |state| Todo.focus_target(state, target),
}

task_editor_entry : Todo.Model, Todo.TaskIndex -> KeyboardFocus.Entry(Todo.Model)
task_editor_entry = |model, task_index| {
	focused: match model.focus {
		TaskEditFocus(data) => data.task_index == task_index
		_ => Bool.False
	},
	focus!: |state| match Todo.task_at(state, task_index) {
		Some(task) => Todo.start_edit(state, task_index, LineEditing.selection_at_end(task.label))
		None => state
	},
}
