## Pure model transitions for the native example. The model stores task data
## and current interaction state, never a retained widget description.
import PuriLineEdit

PuriTodo := [].{

	Task : {
		id : U64,
		label : Str,
		completed : Bool,
	}

	Control := [ToggleTask(U64), RemoveTask(U64)]
	Focus := [DraftFocus(PuriLineEdit.LineEditSelection), ControlFocus(Control), NoFocus]

	Model : {
		draft : Str,
		focus : Focus,
		items : List(Task),
		next_id : U64,
	}

	initial : Model
	initial = { draft: "", focus: NoFocus, items: [], next_id: 1 }

	focus_draft : Model, PuriLineEdit.LineEditSelection -> Model
	focus_draft = |model, selection| { ..model, focus: DraftFocus(selection) }

	change_draft : Model, Str, PuriLineEdit.LineEditSelection -> Model
	change_draft = |model, draft, selection| { ..model, draft, focus: DraftFocus(selection) }

	submit_draft : Model -> Model
	submit_draft = |model| {
		trimmed = Str.trim(model.draft)
		if Str.is_empty(trimmed) {
			{ ..model, focus: NoFocus }
		} else {
			new_task = { id: model.next_id, label: trimmed, completed: Bool.False }
			{
				..model,
				draft: "",
				focus: NoFocus,
				items: List.append(model.items, new_task),
				next_id: model.next_id + 1,
			}
		}
	}

	focus_toggle : Model, U64 -> Model
	focus_toggle = |model, id| { ..model, focus: ControlFocus(ToggleTask(id)) }

	focus_remove : Model, U64 -> Model
	focus_remove = |model, id| { ..model, focus: ControlFocus(RemoveTask(id)) }

	toggle : Model, U64 -> Model
	toggle = |model, id| {
		var $items = []
		for item in model.items {
			next = if item.id == id { ..item, completed: !(item.completed) } else item
			$items = List.append($items, next)
		}
		{ ..model, items: $items }
	}

	remove : Model, U64 -> Model
	remove = |model, id| {
		var $items = []
		for item in model.items {
			if item.id != id {
				$items = List.append($items, item)
			}
		}
		{ ..model, focus: NoFocus, items: $items }
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
}
