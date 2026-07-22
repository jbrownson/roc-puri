app [main!] { test_host: platform "../test-platform/main.roc" }

import PuriLineEdit
import PuriTodo

no_focus : PuriTodo.Focus -> Bool
no_focus = |focus| match focus {
	NoFocus => Bool.True
	_ => Bool.False
}

draft_focus_matches : PuriTodo.Focus, PuriLineEdit.LineEditSelection -> Bool
draft_focus_matches = |focus, expected| match focus {
	DraftFocus(selection) => selection.anchor == expected.anchor and selection.focus == expected.focus and PuriLineEdit.is_dragging(selection) == PuriLineEdit.is_dragging(expected)
	_ => Bool.False
}

draft_focused_at_start : PuriTodo.Focus -> Bool
draft_focused_at_start = |focus| draft_focus_matches(focus, PuriLineEdit.empty_selection)

task_edit_focus_matches : PuriTodo.Focus, U64, PuriLineEdit.LineEditSelection -> Bool
task_edit_focus_matches = |focus, expected_id, expected| match focus {
	TaskEditFocus(data) => data.id == expected_id and data.selection.anchor == expected.anchor and data.selection.focus == expected.focus
	_ => Bool.False
}

task_matches_at : List(PuriTodo.Task), U64, U64, Str, Bool -> Bool
task_matches_at = |items, index, id, label, completed| match List.get(items, index) {
	Ok(item) => item.id == id and item.label == label and item.completed == completed
	Err(_) => Bool.False
}

submit_trims_and_assigns_stable_ids! : () => Bool
submit_trims_and_assigns_stable_ids! = || {
	selection = PuriLineEdit.selection_at_end("  one  ")
	first = PuriTodo.submit_draft(PuriTodo.change_draft(PuriTodo.initial, "  one  ", selection))
	second_selection = PuriLineEdit.selection_at_end("two")
	second = PuriTodo.submit_draft(PuriTodo.change_draft(first, "two", second_selection))
	first_matches = task_matches_at(second.items, 0, 1, "one", Bool.False)
	second_matches = task_matches_at(second.items, 1, 2, "two", Bool.False)
	scrolled = PuriTodo.set_scroll_offset(second, 12)
	Str.is_empty(second.draft) and draft_focused_at_start(second.focus) and second.next_id == 3 and second.scroll_to_end and scrolled.scroll_offset == 12 and !(scrolled.scroll_to_end) and List.len(second.items) == 2 and first_matches and second_matches
}

toggle_and_remove_target_only_one_task! : () => Bool
toggle_and_remove_target_only_one_task! = || {
	first = PuriTodo.submit_draft({ ..PuriTodo.initial, draft: "one" })
	second = PuriTodo.submit_draft({ ..first, draft: "two" })
	focused = PuriTodo.focus_toggle(second, 2)
	toggled = PuriTodo.toggle(focused, 2)
	removed = PuriTodo.remove(PuriTodo.focus_remove(toggled, 1), 1)
	remaining_matches = task_matches_at(removed.items, 0, 2, "two", Bool.True)
	PuriTodo.toggle_focused(toggled, 2) and !(PuriTodo.remove_focused(toggled, 2)) and List.len(removed.items) == 1 and remaining_matches and no_focus(removed.focus)
}

add_focus_is_distinct! : () => Bool
add_focus_is_distinct! = || {
	focused = PuriTodo.focus_add(PuriTodo.initial)
	PuriTodo.add_focused(focused) and !(PuriTodo.toggle_focused(focused, 1)) and !(PuriTodo.remove_focused(focused, 1))
}

editing_changes_label_and_finishes_on_edit_control! : () => Bool
editing_changes_label_and_finishes_on_edit_control! = || {
	added = PuriTodo.submit_draft({ ..PuriTodo.initial, draft: "one" })
	start_selection = PuriLineEdit.selection_at_end("one")
	started = PuriTodo.start_edit(added, 1, start_selection)
	next_selection = PuriLineEdit.selection_at_end("renamed")
	changed = PuriTodo.change_label(started, 1, "renamed", next_selection)
	finished = PuriTodo.finish_edit(changed, 1)
	changed_matches = task_matches_at(changed.items, 0, 1, "renamed", Bool.False)
	started_matches = PuriTodo.is_editing(started, 1) and task_edit_focus_matches(started.focus, 1, start_selection)
	changed_matches and started_matches and task_edit_focus_matches(changed.focus, 1, next_selection) and !(PuriTodo.is_editing(finished, 1)) and PuriTodo.edit_focused(finished, 1)
}

removing_edited_task_clears_editing! : () => Bool
removing_edited_task_clears_editing! = || {
	added = PuriTodo.submit_draft({ ..PuriTodo.initial, draft: "one" })
	editing = PuriTodo.start_edit(added, 1, PuriLineEdit.empty_selection)
	removed = PuriTodo.remove(editing, 1)
	List.is_empty(removed.items) and !(PuriTodo.is_editing(removed, 1)) and no_focus(removed.focus)
}

empty_submission_preserves_draft_and_focus! : () => Bool
empty_submission_preserves_draft_and_focus! = || {
	selection = PuriLineEdit.selection_at_end("   ")
	model = PuriTodo.change_draft(PuriTodo.initial, "   ", selection)
	next = PuriTodo.submit_draft(model)
	focus_preserved = draft_focus_matches(next.focus, selection)
	blurred = PuriTodo.clear_focus(next)
	next.draft == "   " and List.is_empty(next.items) and next.next_id == 1 and focus_preserved and no_focus(blurred.focus)
}

main! = || if submit_trims_and_assigns_stable_ids!() and toggle_and_remove_target_only_one_task!() and add_focus_is_distinct!() and editing_changes_label_and_finishes_on_edit_control!() and removing_edited_task_clears_editing!() and empty_submission_preserves_draft_and_focus!() 0 else 1
