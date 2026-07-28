## Pure model transitions for the native example. The model stores task data
## and current interaction state, never a retained widget description.
import puri.LineEditing
import puri.Reorder
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
	EditSession : { task_index : TaskIndex, original_label : Str }
	TaskEditState : { task_index : TaskIndex, selection : LineEditing.SelectionState }
	Focus := [DraftFocus(LineEditing.SelectionState), TaskEditFocus(TaskEditState), ControlFocus(FocusTarget), NoFocus]

	Model : {
		draft : Str,
		# At most one task editor is visible. Leaving it commits; Escape cancels.
		edit_session : [Some(EditSession), None],
		focus : Focus,
		# The task list remains unchanged during a drag. This transient preview
		# only tells rendering which row floats and where its empty gap belongs.
		drag : Reorder.State,
		tasks : List(Task),
		scroll_position : ScrollView.Position,
	}

	initial : Model
	initial = {
		draft: "",
		edit_session: None,
		focus: NoFocus,
		drag: Reorder.idle,
		tasks: [],
		scroll_position: AtOffset(0),
	}

	task_at : Model, TaskIndex -> [Some(Task), None]
	task_at = |model, task_index| match List.get(model.tasks, task_index) {
		Ok(task) => Some(task)
		Err(_) => None
	}

	focus_draft : Model, LineEditing.SelectionState -> Model
	focus_draft = |model, selection| commit_active_edit({ ..model, focus: DraftFocus(selection) })

	change_draft : Model, Str, LineEditing.SelectionState -> Model
	change_draft = |model, draft, selection| { ..model, draft, focus: DraftFocus(selection) }

	clear_focus : Model -> Model
	clear_focus = |model| commit_active_edit({ ..model, focus: NoFocus })

	set_scroll_position : Model, ScrollView.Position -> Model
	set_scroll_position = |model, position| { ..model, scroll_position: position }

	set_drag : Model, Reorder.State -> Model
	set_drag = |model, drag| { ..model, drag }

	reorder : Model, TaskIndex, TaskIndex -> Model
	reorder = |model, source_index, gap_index| if source_index < List.len(model.tasks) and gap_index < List.len(model.tasks) {
		tasks = Reorder.move(model.tasks, source_index, gap_index)
		edit_session = match model.edit_session {
			Some(session) => Some({ ..session, task_index: Reorder.move_index(session.task_index, source_index, gap_index) })
			None => None
		}
		focus = move_focus(model.focus, source_index, gap_index)
		{ ..model, edit_session, focus, tasks }
	} else {
		model
	}

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
	focus_target = |model, target| commit_active_edit({ ..model, focus: ControlFocus(target) })

	start_edit : Model, TaskIndex, LineEditing.SelectionState -> Model
	start_edit = |model, task_index, selection| match model.edit_session {
		Some(session) if session.task_index == task_index => { ..model, focus: TaskEditFocus({ task_index, selection }) }
		_ => {
			prepared = commit_active_edit({ ..model, focus: TaskEditFocus({ task_index, selection }) })
			match prepared.focus {
				TaskEditFocus(data) => match Todo.task_at(prepared, data.task_index) {
					Some(task) => { ..prepared, edit_session: Some({ task_index: data.task_index, original_label: task.label }) }
					None => { ..prepared, focus: NoFocus }
				}
				_ => prepared
			}
		}
	}

	change_label : Model, TaskIndex, Str, LineEditing.SelectionState -> Model
	change_label = |model, task_index, label, selection| {
		tasks = List.map_with_index(model.tasks, |task, index| if index == task_index { ..task, label } else task)
		{ ..model, focus: TaskEditFocus({ task_index, selection }), tasks }
	}

	finish_edit : Model, TaskIndex -> Model
	finish_edit = |model, task_index| Todo.focus_target(model, EditButton(task_index))

	cancel_edit : Model -> Model
	cancel_edit = |model| match model.edit_session {
		Some(session) => {
			tasks = List.map_with_index(model.tasks, |task, index| if index == session.task_index { ..task, label: session.original_label } else task)
			{ ..model, edit_session: None, focus: NoFocus, tasks }
		}
		None => { ..model, focus: NoFocus }
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
			edit_session = match model.edit_session {
				Some(session) => match shift_index_after_remove(session.task_index, removed_index) {
					Some(next_index) => Some({ ..session, task_index: next_index })
					None => None
				}
				None => None
			}
			focus = shift_focus_after_remove(model.focus, removed_index)
			{ ..model, drag: Reorder.idle, edit_session, focus, tasks: $tasks }
		}
	}

	target_focused : Model, FocusTarget -> Bool
	target_focused = |model, target| match model.focus {
		ControlFocus(focused) => focused == target
		_ => Bool.False
	}

	is_editing : Model, TaskIndex -> Bool
	is_editing = |model, task_index| match model.edit_session {
		Some(session) => session.task_index == task_index
		None => Bool.False
	}
}

commit_active_edit : Todo.Model -> Todo.Model
commit_active_edit = |model| match model.edit_session {
	Some(session) => match Todo.task_at(model, session.task_index) {
		Some(task) => {
			trimmed = Str.trim(task.label)
			if Str.is_empty(trimmed) {
				Todo.remove(model, session.task_index)
			} else {
				tasks = List.map_with_index(model.tasks, |current, index| if index == session.task_index { ..current, label: trimmed } else current)
				{ ..model, edit_session: None, tasks }
			}
		}
		None => { ..model, edit_session: None }
	}
	None => model
}

move_focus_target : Todo.FocusTarget, Todo.TaskIndex, Todo.TaskIndex -> Todo.FocusTarget
move_focus_target = |target, source_index, gap_index| match target {
	AddButton => AddButton
	EditButton(task_index) => EditButton(Reorder.move_index(task_index, source_index, gap_index))
	TaskCheckbox(task_index) => TaskCheckbox(Reorder.move_index(task_index, source_index, gap_index))
	DeleteButton(task_index) => DeleteButton(Reorder.move_index(task_index, source_index, gap_index))
}

move_focus : Todo.Focus, Todo.TaskIndex, Todo.TaskIndex -> Todo.Focus
move_focus = |focus, source_index, gap_index| match focus {
	DraftFocus(_) | NoFocus => focus
	TaskEditFocus({ task_index, selection }) => TaskEditFocus({ task_index: Reorder.move_index(task_index, source_index, gap_index), selection })
	ControlFocus(target) => ControlFocus(move_focus_target(target, source_index, gap_index))
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
