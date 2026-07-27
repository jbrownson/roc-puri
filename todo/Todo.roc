## Pure model transitions for the native example. The model stores task data
## and current interaction state, never a retained widget description.
import puri.LineEdit

Todo := [].{

	Task : {
		id : U64,
		label : Str,
		completed : Bool,
	}

	Control := [AddTask, EditTask(U64), ToggleTask(U64), RemoveTask(U64)]
	TaskEditState : { id : U64, selection : LineEdit.SelectionState }
	Focus := [DraftFocus(LineEdit.SelectionState), TaskEditFocus(TaskEditState), ControlFocus(Control), NoFocus]

	Model : {
		draft : Str,
		# Editing visibility is independent of keyboard focus, so Done can take
		# focus while the task's editor remains on screen.
		editing_id : [Some(U64), None],
		focus : Focus,
		items : List(Task),
		next_id : U64,
		scroll_offset : F32,
		scroll_to_end : Bool,
	}

	initial : Model
	initial = {
		draft: "",
		editing_id: None,
		focus: NoFocus,
		items: [],
		next_id: 1,
		scroll_offset: 0,
		scroll_to_end: Bool.False,
	}

	TaskUpdate : Task -> Task

	update_task : List(Task), U64, TaskUpdate -> List(Task)
	update_task = |items, id, update| {
		var $next_items = []
		for item in items {
			next = if item.id == id update(item) else item
			$next_items = List.append($next_items, next)
		}
		$next_items
	}

	focus_draft : Model, LineEdit.SelectionState -> Model
	focus_draft = |model, selection| { ..model, focus: DraftFocus(selection) }

	change_draft : Model, Str, LineEdit.SelectionState -> Model
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
				focus: DraftFocus(LineEdit.empty_selection),
				items: List.append(model.items, new_task),
				next_id: model.next_id + 1,
				scroll_to_end: Bool.True,
			}
		}
	}

	focus_toggle : Model, U64 -> Model
	focus_toggle = |model, id| { ..model, focus: ControlFocus(ToggleTask(id)) }

	focus_remove : Model, U64 -> Model
	focus_remove = |model, id| { ..model, focus: ControlFocus(RemoveTask(id)) }

	focus_add : Model -> Model
	focus_add = |model| { ..model, focus: ControlFocus(AddTask) }

	start_edit : Model, U64, LineEdit.SelectionState -> Model
	start_edit = |model, id, selection| { ..model, editing_id: Some(id), focus: TaskEditFocus({ id, selection }) }

	change_label : Model, U64, Str, LineEdit.SelectionState -> Model
	change_label = |model, id, label, selection| {
		items = Todo.update_task(model.items, id, |item| { ..item, label })
		{ ..model, editing_id: Some(id), focus: TaskEditFocus({ id, selection }), items }
	}

	finish_edit : Model, U64 -> Model
	finish_edit = |model, id| {
		var $label = None
		for item in model.items {
			if item.id == id {
				$label = Some(Str.trim(item.label))
			}
		}
		match $label {
			Some(trimmed) => if Str.is_empty(trimmed) {
				Todo.remove(model, id)
			} else {
				items = Todo.update_task(model.items, id, |item| { ..item, label: trimmed })
				{ ..model, editing_id: None, focus: ControlFocus(EditTask(id)), items }
			}
			None => model
		}
	}

	focus_edit : Model, U64 -> Model
	focus_edit = |model, id| { ..model, focus: ControlFocus(EditTask(id)) }

	toggle : Model, U64 -> Model
	toggle = |model, id| {
		items = Todo.update_task(model.items, id, |item| { ..item, completed: !(item.completed) })
		{ ..model, items }
	}

	remove : Model, U64 -> Model
	remove = |model, id| {
		var $items = []
		for item in model.items {
			if item.id != id {
				$items = List.append($items, item)
			}
		}
		editing_id = match model.editing_id {
			Some(current_id) => if current_id == id None else model.editing_id
			None => None
		}
		{ ..model, editing_id, focus: NoFocus, items: $items }
	}

	toggle_focused : Model, U64 -> Bool
	toggle_focused = |model, id| match model.focus {
		ControlFocus(ToggleTask(focused_id)) => focused_id == id
		_ => Bool.False
	}

	remove_focused : Model, U64 -> Bool
	remove_focused = |model, id| match model.focus {
		ControlFocus(RemoveTask(focused_id)) => focused_id == id
		_ => Bool.False
	}

	add_focused : Model -> Bool
	add_focused = |model| match model.focus {
		ControlFocus(AddTask) => Bool.True
		_ => Bool.False
	}

	edit_focused : Model, U64 -> Bool
	edit_focused = |model, id| match model.focus {
		ControlFocus(EditTask(focused_id)) => focused_id == id
		_ => Bool.False
	}

	is_editing : Model, U64 -> Bool
	is_editing = |model, id| match model.editing_id {
		Some(current_id) => current_id == id
		None => Bool.False
	}
}
