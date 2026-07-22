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
	Str.is_empty(second.draft) and draft_focused_at_start(second.focus) and second.next_id == 3 and List.len(second.items) == 2 and first_matches and second_matches
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

empty_submission_preserves_draft_and_focus! : () => Bool
empty_submission_preserves_draft_and_focus! = || {
	selection = PuriLineEdit.selection_at_end("   ")
	model = PuriTodo.change_draft(PuriTodo.initial, "   ", selection)
	next = PuriTodo.submit_draft(model)
	focus_preserved = draft_focus_matches(next.focus, selection)
	blurred = PuriTodo.clear_focus(next)
	next.draft == "   " and List.is_empty(next.items) and next.next_id == 1 and focus_preserved and no_focus(blurred.focus)
}

main! = || if submit_trims_and_assigns_stable_ids!() and toggle_and_remove_target_only_one_task!() and empty_submission_preserves_draft_and_focus!() 0 else 1
