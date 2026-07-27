app [main!] {
	test_host: platform "./tests/platform/main.roc",
	puri: "../puri/main.roc",
}

import puri.Event
import puri.Handler
import puri.LineEdit
import Todo
import TodoFocus

no_focus : Todo.Focus -> Bool
no_focus = |focus| match focus {
	NoFocus => Bool.True
	_ => Bool.False
}

draft_focus_matches : Todo.Focus, LineEdit.LineEditSelection -> Bool
draft_focus_matches = |focus, expected| match focus {
	DraftFocus(selection) => selection.anchor == expected.anchor and selection.focus == expected.focus and LineEdit.is_dragging(selection) == LineEdit.is_dragging(expected)
	_ => Bool.False
}

draft_focused_at_start : Todo.Focus -> Bool
draft_focused_at_start = |focus| draft_focus_matches(focus, LineEdit.empty_selection)

task_edit_focus_matches : Todo.Focus, U64, LineEdit.LineEditSelection -> Bool
task_edit_focus_matches = |focus, expected_id, expected| match focus {
	TaskEditFocus(data) => data.id == expected_id and data.selection.anchor == expected.anchor and data.selection.focus == expected.focus
	_ => Bool.False
}

control_focus_matches : Todo.Focus, Todo.Control -> Bool
control_focus_matches = |focus, expected| match (focus, expected) {
	(ControlFocus(AddTask), AddTask) => Bool.True
	(ControlFocus(EditTask(actual_id)), EditTask(expected_id)) => actual_id == expected_id
	(ControlFocus(ToggleTask(actual_id)), ToggleTask(expected_id)) => actual_id == expected_id
	(ControlFocus(RemoveTask(actual_id)), RemoveTask(expected_id)) => actual_id == expected_id
	_ => Bool.False
}

task_matches_at : List(Todo.Task), U64, U64, Str, Bool -> Bool
task_matches_at = |items, index, id, label, completed| match List.get(items, index) {
	Ok(item) => item.id == id and item.label == label and item.completed == completed
	Err(_) => Bool.False
}

submit_trims_and_assigns_stable_ids! : () => Bool
submit_trims_and_assigns_stable_ids! = || {
	selection = LineEdit.selection_at_end("  one  ")
	first = Todo.submit_draft(Todo.change_draft(Todo.initial, "  one  ", selection))
	second_selection = LineEdit.selection_at_end("two")
	second = Todo.submit_draft(Todo.change_draft(first, "two", second_selection))
	first_matches = task_matches_at(second.items, 0, 1, "one", Bool.False)
	second_matches = task_matches_at(second.items, 1, 2, "two", Bool.False)
	scrolled = Todo.set_scroll_offset(second, 12)
	Str.is_empty(second.draft) and draft_focused_at_start(second.focus) and second.next_id == 3 and second.scroll_to_end and scrolled.scroll_offset == 12 and !(scrolled.scroll_to_end) and List.len(second.items) == 2 and first_matches and second_matches
}

toggle_and_remove_target_only_one_task! : () => Bool
toggle_and_remove_target_only_one_task! = || {
	first = Todo.submit_draft({ ..Todo.initial, draft: "one" })
	second = Todo.submit_draft({ ..first, draft: "two" })
	focused = Todo.focus_toggle(second, 2)
	toggled = Todo.toggle(focused, 2)
	removed = Todo.remove(Todo.focus_remove(toggled, 1), 1)
	remaining_matches = task_matches_at(removed.items, 0, 2, "two", Bool.True)
	Todo.toggle_focused(toggled, 2) and !(Todo.remove_focused(toggled, 2)) and List.len(removed.items) == 1 and remaining_matches and no_focus(removed.focus)
}

add_focus_is_distinct! : () => Bool
add_focus_is_distinct! = || {
	focused = Todo.focus_add(Todo.initial)
	Todo.add_focused(focused) and !(Todo.toggle_focused(focused, 1)) and !(Todo.remove_focused(focused, 1))
}

editing_changes_label_and_finishes_on_edit_control! : () => Bool
editing_changes_label_and_finishes_on_edit_control! = || {
	added = Todo.submit_draft({ ..Todo.initial, draft: "one" })
	start_selection = LineEdit.selection_at_end("one")
	started = Todo.start_edit(added, 1, start_selection)
	next_selection = LineEdit.selection_at_end("  renamed  ")
	changed = Todo.change_label(started, 1, "  renamed  ", next_selection)
	finished = Todo.finish_edit(changed, 1)
	changed_matches = task_matches_at(changed.items, 0, 1, "  renamed  ", Bool.False)
	finished_matches = task_matches_at(finished.items, 0, 1, "renamed", Bool.False)
	started_matches = Todo.is_editing(started, 1) and task_edit_focus_matches(started.focus, 1, start_selection)
	changed_matches and finished_matches and started_matches and task_edit_focus_matches(changed.focus, 1, next_selection) and !(Todo.is_editing(finished, 1)) and Todo.edit_focused(finished, 1)
}

committing_empty_edit_removes_task! : () => Bool
committing_empty_edit_removes_task! = || {
	added = Todo.submit_draft({ ..Todo.initial, draft: "one" })
	editing = Todo.start_edit(added, 1, LineEdit.selection_at_end("one"))
	emptied = Todo.change_label(editing, 1, "   ", LineEdit.selection_at_end("   "))
	finished = Todo.finish_edit(emptied, 1)
	List.is_empty(finished.items) and !(Todo.is_editing(finished, 1)) and no_focus(finished.focus)
}

removing_edited_task_clears_editing! : () => Bool
removing_edited_task_clears_editing! = || {
	added = Todo.submit_draft({ ..Todo.initial, draft: "one" })
	editing = Todo.start_edit(added, 1, LineEdit.empty_selection)
	removed = Todo.remove(editing, 1)
	List.is_empty(removed.items) and !(Todo.is_editing(removed, 1)) and no_focus(removed.focus)
}

empty_submission_preserves_draft_and_focus! : () => Bool
empty_submission_preserves_draft_and_focus! = || {
	selection = LineEdit.selection_at_end("   ")
	model = Todo.change_draft(Todo.initial, "   ", selection)
	next = Todo.submit_draft(model)
	focus_preserved = draft_focus_matches(next.focus, selection)
	blurred = Todo.clear_focus(next)
	next.draft == "   " and List.is_empty(next.items) and next.next_id == 1 and focus_preserved and no_focus(blurred.focus)
}

todo_owns_focus_order! : () => Bool
todo_owns_focus_order! = || {
	first = TodoFocus.move(Todo.initial, Next)
	last = TodoFocus.move(Todo.initial, Previous)
	added = Todo.submit_draft({ ..Todo.initial, draft: "one" })
	from_draft = TodoFocus.move(Todo.focus_draft(added, LineEdit.empty_selection), Next)
	from_add = TodoFocus.move(from_draft, Next)
	from_toggle = TodoFocus.move(from_add, Next)
	from_edit = TodoFocus.move(from_toggle, Next)
	wrapped = TodoFocus.move(from_edit, Next)
	draft_focused_at_start(first.focus)
		and control_focus_matches(last.focus, AddTask)
			and control_focus_matches(from_draft.focus, AddTask)
				and control_focus_matches(from_add.focus, ToggleTask(1))
					and control_focus_matches(from_toggle.focus, EditTask(1))
						and control_focus_matches(from_edit.focus, RemoveTask(1))
							and draft_focused_at_start(wrapped.focus)
}

editing_adds_its_editor_to_the_app_order! : () => Bool
editing_adds_its_editor_to_the_app_order! = || {
	added = Todo.submit_draft({ ..Todo.initial, draft: "one" })
	editing = Todo.start_edit(added, 1, LineEdit.empty_selection)
	toggle = Todo.focus_toggle(editing, 1)
	editor = TodoFocus.move(toggle, Next)
	edit_button = TodoFocus.move(editor, Next)
	back_to_editor = TodoFocus.move(edit_button, Previous)
	at_end = LineEdit.selection_at_end("one")
	task_edit_focus_matches(editor.focus, 1, at_end)
		and control_focus_matches(edit_button.focus, EditTask(1))
			and task_edit_focus_matches(back_to_editor.focus, 1, at_end)
}

tab_is_an_ordinary_app_event! : () => Bool
tab_is_an_ordinary_app_event! = || {
	tab = { key: Named(Tab), state: KeyDown, modifiers: Event.empty_modifiers }
	shift_tab = { ..tab, modifiers: { ..Event.empty_modifiers, shift: Bool.True } }
	ctrl_tab = { ..tab, modifiers: { ..Event.empty_modifiers, ctrl: Bool.True } }
	forward = Handler.dispatch!(TodoFocus.handler, Todo.initial, Key(tab))
	backward = Handler.dispatch!(TodoFocus.handler, Todo.initial, Key(shift_tab))
	modified = Handler.dispatch!(TodoFocus.handler, Todo.initial, Key(ctrl_tab))
	forward_matches = match forward {
		Handled(model) => draft_focused_at_start(model.focus)
		Declined => Bool.False
	}
	backward_matches = match backward {
		Handled(model) => control_focus_matches(model.focus, AddTask)
		Declined => Bool.False
	}
	forward_matches and backward_matches and modified == Declined
}

main! = || if submit_trims_and_assigns_stable_ids!() and toggle_and_remove_target_only_one_task!() and add_focus_is_distinct!() and editing_changes_label_and_finishes_on_edit_control!() and committing_empty_edit_removes_task!() and removing_edited_task_clears_editing!() and empty_submission_preserves_draft_and_focus!() and todo_owns_focus_order!() and editing_adds_its_editor_to_the_app_order!() and tab_is_an_ordinary_app_event!() 0 else 1
