## Todo-specific keyboard focus policy.
##
## Puri widgets consume application-supplied focused state but know nothing
## about focus domains or traversal. This module chooses the controls that
## participate in this application's single Tab order.
import puri.Event
import puri.Handler
import puri.LineEditing
import Todo

TodoFocus := [].{

	Direction := [Next, Previous]
	Events(events) : [Key(Event.KeyEvent), ..events]

	handler : Handler(Todo.Model, Events(events))
	handler = Handler.from_function(
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

	move : Todo.Model, Direction -> Todo.Model
	move = |model, direction| {
		all = locations(model)
		last_index = List.len(all) - 1
		current_index = match current_location(model.focus) {
			Some(location) => location_index(all, location, 0)
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
			Ok(location) => focus_location(model, location)
			Err(_) => model
		}
	}
}

Location := [DraftLocation, TaskEditorLocation(U64), ControlLocation(Todo.Control)].{
	is_eq : _
}

locations : Todo.Model -> List(Location)
locations = |model| {
	var $locations = [DraftLocation, ControlLocation(AddTask)]
	for task in model.tasks {
		$locations = List.append($locations, ControlLocation(ToggleTask(task.id)))
		if Todo.is_editing(model, task.id) {
			$locations = List.append($locations, TaskEditorLocation(task.id))
		}
		$locations = List.append($locations, ControlLocation(EditTask(task.id)))
		$locations = List.append($locations, ControlLocation(RemoveTask(task.id)))
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

location_index : List(Location), Location, U64 -> [Some(U64), None]
location_index = |all, wanted, index| if index >= List.len(all) {
	None
} else match List.get(all, index) {
	Ok(location) => if location == wanted Some(index) else location_index(all, wanted, index + 1)
	Err(_) => None
}

focus_location : Todo.Model, Location -> Todo.Model
focus_location = |model, location| match location {
	DraftLocation => Todo.focus_draft(model, LineEditing.selection_at_end(model.draft))
	ControlLocation(control) => { ..model, focus: ControlFocus(control) }
	TaskEditorLocation(id) => match Todo.find_task(model, id) {
		Some(task) => Todo.start_edit(model, id, LineEditing.selection_at_end(task.label))
		None => model
	}
}
