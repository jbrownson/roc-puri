## Todo-specific keyboard focus policy.
##
## Puri widgets consume application-supplied focused state but know nothing
## about focus domains or traversal. This module chooses the controls that
## participate in this application's single Tab order.
import puri.PuriEvent
import puri.PuriHandler
import puri.PuriLineEdit
import Todo

TodoFocus := [].{

	Location := [DraftLocation, TaskEditorLocation(U64), ControlLocation(Todo.Control)]
	Direction := [Next, Previous]
	Events(events) : [Key(PuriEvent.KeyEvent), ..events]

	handler : PuriHandler.Handler(Todo.Model, Events(events))
	handler = PuriHandler.on_event(
		|model, event| match event {
			Key(key) => match (key.state, key.key) {
				(KeyDown, Named(Tab)) => if key.modifiers.alt or key.modifiers.ctrl or key.modifiers.meta {
					Declined
				} else {
					direction = if key.modifiers.shift Previous else Next
					Handled(TodoFocus.move(model, direction))
				}
				_ => Declined
			}
			_ => Declined
		},
	)

	locations : Todo.Model -> List(Location)
	locations = |model| {
		var $locations = [DraftLocation, ControlLocation(AddTask)]
		for item in model.items {
			$locations = List.append($locations, ControlLocation(ToggleTask(item.id)))
			if Todo.is_editing(model, item.id) {
				$locations = List.append($locations, TaskEditorLocation(item.id))
			}
			$locations = List.append($locations, ControlLocation(EditTask(item.id)))
			$locations = List.append($locations, ControlLocation(RemoveTask(item.id)))
		}
		$locations
	}

	current_location : Todo.Focus -> [Some(Location), None]
	current_location = |focus| match focus {
		DraftFocus(_) => Some(DraftLocation)
		TaskEditFocus(data) => Some(TaskEditorLocation(data.id))
		ControlFocus(control) => Some(ControlLocation(control))
		NoFocus => None
	}

	same_control : Todo.Control, Todo.Control -> Bool
	same_control = |first, second| match (first, second) {
		(AddTask, AddTask) => Bool.True
		(EditTask(first_id), EditTask(second_id)) => first_id == second_id
		(ToggleTask(first_id), ToggleTask(second_id)) => first_id == second_id
		(RemoveTask(first_id), RemoveTask(second_id)) => first_id == second_id
		_ => Bool.False
	}

	same_location : Location, Location -> Bool
	same_location = |first, second| match (first, second) {
		(DraftLocation, DraftLocation) => Bool.True
		(TaskEditorLocation(first_id), TaskEditorLocation(second_id)) => first_id == second_id
		(ControlLocation(first_control), ControlLocation(second_control)) => TodoFocus.same_control(first_control, second_control)
		_ => Bool.False
	}

	location_index : List(Location), Location, U64 -> [Some(U64), None]
	location_index = |all, wanted, index| if index >= List.len(all) {
		None
	} else match List.get(all, index) {
		Ok(location) => if TodoFocus.same_location(location, wanted) Some(index) else TodoFocus.location_index(all, wanted, index + 1)
		Err(_) => None
	}

	focus_location : Todo.Model, Location -> Todo.Model
	focus_location = |model, location| match location {
		DraftLocation => Todo.focus_draft(model, PuriLineEdit.selection_at_end(model.draft))
		ControlLocation(control) => { ..model, focus: ControlFocus(control) }
		TaskEditorLocation(id) => {
			var $label = None
			for item in model.items {
				if item.id == id {
					$label = Some(item.label)
				}
			}
			match $label {
				Some(label) => Todo.start_edit(model, id, PuriLineEdit.selection_at_end(label))
				None => model
			}
		}
	}

	move : Todo.Model, Direction -> Todo.Model
	move = |model, direction| {
		all = TodoFocus.locations(model)
		last_index = List.len(all) - 1
		current_index = match TodoFocus.current_location(model.focus) {
			Some(location) => TodoFocus.location_index(all, location, 0)
			None => None
		}
		next_index = match current_index {
			Some(index) => match direction {
				Next => if index >= last_index 0 else index + 1
				Previous => if index == 0 last_index else index - 1
			}
			None => match direction {
				Next => 0
				Previous => last_index
			}
		}
		match List.get(all, next_index) {
			Ok(location) => TodoFocus.focus_location(model, location)
			Err(_) => model
		}
	}
}
