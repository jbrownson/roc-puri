## Pure model transitions for the native example. The model stores task data
## and current interaction state, never a retained widget description.
import puri.LineEditing

Todo := [].{

	Task : {
		id : U64,
		label : Str,
		completed : Bool,
	}

	Control := [AddTask, EditTask(U64), ToggleTask(U64), RemoveTask(U64)].{
		is_eq : _
	}
	TaskEditState : { id : U64, selection : LineEditing.SelectionState }
	Focus := [DraftFocus(LineEditing.SelectionState), TaskEditFocus(TaskEditState), ControlFocus(Control), NoFocus]

	Model : {
		draft : Str,
		# Editing visibility is independent of keyboard focus, so Done can take
		# focus while the task's editor remains on screen.
		editing_task_id : [Some(U64), None],
		focus : Focus,
		tasks : List(Task),
		next_id : U64,
		scroll_offset : F32,
		scroll_to_end : Bool,
	}

	initial : Model
	initial = {
		draft: "",
		editing_task_id: None,
		focus: NoFocus,
		tasks: [],
		next_id: 1,
		scroll_offset: 0,
		scroll_to_end: Bool.False,
	}

	find_task : Model, U64 -> [Some(Task), None]
	find_task = |model, id| {
		var $found = None
		for task in model.tasks {
			if task.id == id {
				$found = Some(task)
			}
		}
		$found
	}

	focus_draft : Model, LineEditing.SelectionState -> Model
	focus_draft = |model, selection| { ..model, focus: DraftFocus(selection) }

	change_draft : Model, Str, LineEditing.SelectionState -> Model
	change_draft = |model, draft, selection| { ..model, draft, focus: DraftFocus(selection) }

	clear_focus : Model -> Model
	clear_focus = |model| { ..model, focus: NoFocus }

	set_scroll_offset : Model, F32 -> Model
	set_scroll_offset = |model, offset| { ..model, scroll_offset: offset, scroll_to_end: Bool.False }

	submit_draft : Model -> Model
	submit_draft = |model| {
		trimmed = Str.trim(model.draft)
		if Str.is_empty(trimmed) {
			model
		} else {
			new_task = { id: model.next_id, label: trimmed, completed: Bool.False }
			{
				..model,
				draft: "",
				focus: DraftFocus(LineEditing.empty_selection),
				tasks: List.append(model.tasks, new_task),
				next_id: model.next_id + 1,
				scroll_to_end: Bool.True,
			}
		}
	}

	focus_control : Model, Control -> Model
	focus_control = |model, control| { ..model, focus: ControlFocus(control) }

	start_edit : Model, U64, LineEditing.SelectionState -> Model
	start_edit = |model, id, selection| { ..model, editing_task_id: Some(id), focus: TaskEditFocus({ id, selection }) }

	change_label : Model, U64, Str, LineEditing.SelectionState -> Model
	change_label = |model, id, label, selection| {
		tasks = update_task(model.tasks, id, |task| { ..task, label })
		{ ..model, editing_task_id: Some(id), focus: TaskEditFocus({ id, selection }), tasks }
	}

	finish_edit : Model, U64 -> Model
	finish_edit = |model, id| match Todo.find_task(model, id) {
		Some(task) => {
			trimmed = Str.trim(task.label)
			if Str.is_empty(trimmed) {
				Todo.remove(model, id)
			} else {
				tasks = update_task(model.tasks, id, |current| { ..current, label: trimmed })
				{ ..model, editing_task_id: None, focus: ControlFocus(EditTask(id)), tasks }
			}
		}
		None => model
	}

	toggle : Model, U64 -> Model
	toggle = |model, id| {
		tasks = update_task(model.tasks, id, |task| { ..task, completed: !(task.completed) })
		{ ..model, tasks }
	}

	remove : Model, U64 -> Model
	remove = |model, id| {
		var $tasks = []
		for task in model.tasks {
			if task.id != id {
				$tasks = List.append($tasks, task)
			}
		}
		editing_task_id = match model.editing_task_id {
			Some(current_id) => if current_id == id None else model.editing_task_id
			None => None
		}
		{ ..model, editing_task_id, focus: NoFocus, tasks: $tasks }
	}

	control_focused : Model, Control -> Bool
	control_focused = |model, control| match model.focus {
		ControlFocus(focused) => focused == control
		_ => Bool.False
	}

	is_editing : Model, U64 -> Bool
	is_editing = |model, id| match model.editing_task_id {
		Some(current_id) => current_id == id
		None => Bool.False
	}
}

TaskUpdate : Todo.Task -> Todo.Task

update_task : List(Todo.Task), U64, TaskUpdate -> List(Todo.Task)
update_task = |tasks, id, update| {
	var $next_tasks = []
	for task in tasks {
		next = if task.id == id update(task) else task
		$next_tasks = List.append($next_tasks, next)
	}
	$next_tasks
}
