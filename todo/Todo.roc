## Pure model transitions for the native example. The model stores task data
## and current interaction state, never a retained widget description.
import puri.LineEditing
import puri.ScrollView

Todo := [].{

	Task : {
		label : Str,
		completed : Bool,
	}

	# A TaskIndex is a position in the current Model, not a stable identity.
	# One-shot handlers capture it; list-changing transitions update stored uses.
	TaskIndex : U64
	FocusTarget := [AddButton, EditButton(TaskIndex), TaskCheckbox(TaskIndex), DeleteButton(TaskIndex)].{
		is_eq : _
	}
	TaskEditState : { task_index : TaskIndex, selection : LineEditing.SelectionState }
	Focus := [DraftFocus(LineEditing.SelectionState), TaskEditFocus(TaskEditState), ControlFocus(FocusTarget), NoFocus]

	Model : {
		draft : Str,
		# Editing visibility is independent of keyboard focus, so Done can take
		# focus while the task's editor remains on screen.
		editing_task_index : [Some(TaskIndex), None],
		focus : Focus,
		tasks : List(Task),
		scroll_position : ScrollView.Position,
	}

	initial : Model
	initial = {
		draft: "",
		editing_task_index: None,
		focus: NoFocus,
		tasks: [],
		scroll_position: AtOffset(0),
	}

	task_at : Model, TaskIndex -> [Some(Task), None]
	task_at = |model, task_index| match List.get(model.tasks, task_index) {
		Ok(task) => Some(task)
		Err(_) => None
	}

	focus_draft : Model, LineEditing.SelectionState -> Model
	focus_draft = |model, selection| { ..model, focus: DraftFocus(selection) }

	change_draft : Model, Str, LineEditing.SelectionState -> Model
	change_draft = |model, draft, selection| { ..model, draft, focus: DraftFocus(selection) }

	clear_focus : Model -> Model
	clear_focus = |model| { ..model, focus: NoFocus }

	set_scroll_position : Model, ScrollView.Position -> Model
	set_scroll_position = |model, position| { ..model, scroll_position: position }

	submit_draft : Model -> Model
	submit_draft = |model| {
		trimmed = Str.trim(model.draft)
		if Str.is_empty(trimmed) {
			model
		} else {
			new_task = { label: trimmed, completed: Bool.False }
			{
				..model,
				draft: "",
				focus: DraftFocus(LineEditing.empty_selection),
				tasks: List.append(model.tasks, new_task),
				scroll_position: AtEnd,
			}
		}
	}

	focus_target : Model, FocusTarget -> Model
	focus_target = |model, target| { ..model, focus: ControlFocus(target) }

	start_edit : Model, TaskIndex, LineEditing.SelectionState -> Model
	start_edit = |model, task_index, selection| { ..model, editing_task_index: Some(task_index), focus: TaskEditFocus({ task_index, selection }) }

	change_label : Model, TaskIndex, Str, LineEditing.SelectionState -> Model
	change_label = |model, task_index, label, selection| {
		tasks = List.map_with_index(model.tasks, |task, index| if index == task_index { ..task, label } else task)
		{ ..model, editing_task_index: Some(task_index), focus: TaskEditFocus({ task_index, selection }), tasks }
	}

	finish_edit : Model, TaskIndex -> Model
	finish_edit = |model, task_index| match Todo.task_at(model, task_index) {
		Some(task) => {
			trimmed = Str.trim(task.label)
			if Str.is_empty(trimmed) {
				Todo.remove(model, task_index)
			} else {
				tasks = List.map_with_index(model.tasks, |current, index| if index == task_index { ..current, label: trimmed } else current)
				{ ..model, editing_task_index: None, focus: ControlFocus(EditButton(task_index)), tasks }
			}
		}
		None => model
	}

	toggle : Model, TaskIndex -> Model
	toggle = |model, task_index| {
		tasks = List.map_with_index(model.tasks, |task, index| if index == task_index { ..task, completed: !(task.completed) } else task)
		{ ..model, tasks }
	}

	remove : Model, TaskIndex -> Model
	remove = |model, removed_index| match List.get(model.tasks, removed_index) {
		Err(_) => model
		Ok(_) => {
			var $tasks = []
			var $task_index = 0
			for task in model.tasks {
				if $task_index != removed_index {
					$tasks = List.append($tasks, task)
				}
				$task_index = $task_index + 1
			}
			editing_task_index = match model.editing_task_index {
				Some(current_index) => shift_index_after_remove(current_index, removed_index)
				None => None
			}
			focus = shift_focus_after_remove(model.focus, removed_index)
			{ ..model, editing_task_index, focus, tasks: $tasks }
		}
	}

	target_focused : Model, FocusTarget -> Bool
	target_focused = |model, target| match model.focus {
		ControlFocus(focused) => focused == target
		_ => Bool.False
	}

	is_editing : Model, TaskIndex -> Bool
	is_editing = |model, task_index| match model.editing_task_index {
		Some(current_index) => current_index == task_index
		None => Bool.False
	}
}

shift_index_after_remove : Todo.TaskIndex, Todo.TaskIndex -> [Some(Todo.TaskIndex), None]
shift_index_after_remove = |task_index, removed_index| if task_index == removed_index {
	None
} else if task_index > removed_index {
	Some(task_index - 1)
} else {
	Some(task_index)
}

shift_focus_target_after_remove : Todo.FocusTarget, Todo.TaskIndex -> [Some(Todo.FocusTarget), None]
shift_focus_target_after_remove = |target, removed_index| match target {
	AddButton => Some(AddButton)
	EditButton(task_index) => match shift_index_after_remove(task_index, removed_index) {
		Some(next_index) => Some(EditButton(next_index))
		None => None
	}
	TaskCheckbox(task_index) => match shift_index_after_remove(task_index, removed_index) {
		Some(next_index) => Some(TaskCheckbox(next_index))
		None => None
	}
	DeleteButton(task_index) => match shift_index_after_remove(task_index, removed_index) {
		Some(next_index) => Some(DeleteButton(next_index))
		None => None
	}
}

shift_focus_after_remove : Todo.Focus, Todo.TaskIndex -> Todo.Focus
shift_focus_after_remove = |focus, removed_index| match focus {
	DraftFocus(_) | NoFocus => focus
	TaskEditFocus({ task_index, selection }) => match shift_index_after_remove(task_index, removed_index) {
		Some(next_index) => TaskEditFocus({ task_index: next_index, selection })
		None => NoFocus
	}
	ControlFocus(target) => match shift_focus_target_after_remove(target, removed_index) {
		Some(next_target) => ControlFocus(next_target)
		None => NoFocus
	}
}
