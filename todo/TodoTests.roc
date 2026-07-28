app [main!] {
	test_host: platform "./tests/platform/main.roc",
	geometry: "../geometry/main.roc",
	puri: "../puri/main.roc",
}

import geometry.Geometry2d
import puri.Event
import puri.Handler
import puri.KeyboardFocus
import puri.LineEditing
import puri.Reorder
import puri.ScrollView
import Todo
import TodoFocus

no_focus : Todo.Focus -> Bool
no_focus = |focus| match focus {
	NoFocus => Bool.True
	_ => Bool.False
}

draft_focus_matches : Todo.Focus, LineEditing.SelectionState -> Bool
draft_focus_matches = |focus, expected| match focus {
	DraftFocus(selection) => selection.anchor == expected.anchor and selection.focus == expected.focus and LineEditing.is_dragging(selection) == LineEditing.is_dragging(expected)
	_ => Bool.False
}

draft_focused_at_start : Todo.Focus -> Bool
draft_focused_at_start = |focus| draft_focus_matches(focus, LineEditing.empty_selection)

task_edit_focus_matches : Todo.Focus, Todo.TaskIndex, LineEditing.SelectionState -> Bool
task_edit_focus_matches = |focus, expected_index, expected| match focus {
	TaskEditFocus(data) => data.task_index == expected_index and data.selection.anchor == expected.anchor and data.selection.focus == expected.focus
	_ => Bool.False
}

target_focus_matches : Todo.Focus, Todo.FocusTarget -> Bool
target_focus_matches = |focus, expected| match focus {
	ControlFocus(actual) => actual == expected
	_ => Bool.False
}

task_matches_at : List(Todo.Task), Todo.TaskIndex, Str, Bool -> Bool
task_matches_at = |tasks, task_index, label, completed| match List.get(tasks, task_index) {
	Ok(task) => task.label == label and task.completed == completed
	Err(_) => Bool.False
}

submit_trims_and_appends_tasks! : () => Bool
submit_trims_and_appends_tasks! = || {
	selection = LineEditing.selection_at_end("  one  ")
	first = Todo.submit_draft(Todo.change_draft(Todo.initial, "  one  ", selection))
	second_selection = LineEditing.selection_at_end("two")
	second = Todo.submit_draft(Todo.change_draft(first, "two", second_selection))
	first_matches = task_matches_at(second.tasks, 0, "one", Bool.False)
	second_matches = task_matches_at(second.tasks, 1, "two", Bool.False)
	scrolled = Todo.set_scroll_position(second, AtOffset(12))
	Str.is_empty(second.draft) and draft_focused_at_start(second.focus) and second.scroll_position == AtEnd and scrolled.scroll_position == AtOffset(12) and List.len(second.tasks) == 2 and first_matches and second_matches
}

indices_distinguish_identical_tasks! : () => Bool
indices_distinguish_identical_tasks! = || {
	first = Todo.submit_draft({ ..Todo.initial, draft: "same" })
	second = Todo.submit_draft({ ..first, draft: "same" })
	focused = Todo.focus_target(second, TaskCheckbox(1))
	toggled = Todo.toggle(focused, 1)
	removed = Todo.remove(Todo.focus_target(toggled, DeleteButton(0)), 0)
	remaining_matches = task_matches_at(removed.tasks, 0, "same", Bool.True)
	Todo.target_focused(toggled, TaskCheckbox(1)) and !(Todo.target_focused(toggled, DeleteButton(1))) and List.len(removed.tasks) == 1 and remaining_matches and no_focus(removed.focus)
}

add_focus_is_distinct! : () => Bool
add_focus_is_distinct! = || {
	focused = Todo.focus_target(Todo.initial, AddButton)
	Todo.target_focused(focused, AddButton) and !(Todo.target_focused(focused, TaskCheckbox(0))) and !(Todo.target_focused(focused, DeleteButton(0)))
}

editing_changes_label_and_finishes_on_edit_button! : () => Bool
editing_changes_label_and_finishes_on_edit_button! = || {
	added = Todo.submit_draft({ ..Todo.initial, draft: "one" })
	start_selection = LineEditing.selection_at_end("one")
	started = Todo.start_edit(added, 0, start_selection)
	next_selection = LineEditing.selection_at_end("  renamed  ")
	changed = Todo.change_label(started, 0, "  renamed  ", next_selection)
	finished = Todo.finish_edit(changed, 0)
	changed_matches = task_matches_at(changed.tasks, 0, "  renamed  ", Bool.False)
	finished_matches = task_matches_at(finished.tasks, 0, "renamed", Bool.False)
	started_matches = Todo.is_editing(started, 0) and task_edit_focus_matches(started.focus, 0, start_selection)
	changed_matches and finished_matches and started_matches and task_edit_focus_matches(changed.focus, 0, next_selection) and !(Todo.is_editing(finished, 0)) and Todo.target_focused(finished, EditButton(0))
}

committing_empty_edit_removes_task! : () => Bool
committing_empty_edit_removes_task! = || {
	added = Todo.submit_draft({ ..Todo.initial, draft: "one" })
	editing = Todo.start_edit(added, 0, LineEditing.selection_at_end("one"))
	emptied = Todo.change_label(editing, 0, "   ", LineEditing.selection_at_end("   "))
	finished = Todo.finish_edit(emptied, 0)
	List.is_empty(finished.tasks) and !(Todo.is_editing(finished, 0)) and no_focus(finished.focus)
}

cancelling_edit_restores_original_label! : () => Bool
cancelling_edit_restores_original_label! = || {
	added = Todo.submit_draft({ ..Todo.initial, draft: "one" })
	editing = Todo.start_edit(added, 0, LineEditing.selection_at_end("one"))
	changed = Todo.change_label(editing, 0, "renamed", LineEditing.selection_at_end("renamed"))
	cancelled = Todo.cancel_edit(changed)
	task_matches_at(cancelled.tasks, 0, "one", Bool.False)
		and !(Todo.is_editing(cancelled, 0))
			and no_focus(cancelled.focus)
}

removing_edited_task_clears_editing! : () => Bool
removing_edited_task_clears_editing! = || {
	added = Todo.submit_draft({ ..Todo.initial, draft: "one" })
	editing = Todo.start_edit(added, 0, LineEditing.empty_selection)
	removed = Todo.remove(editing, 0)
	List.is_empty(removed.tasks) and !(Todo.is_editing(removed, 0)) and no_focus(removed.focus)
}

removing_before_a_reference_shifts_its_index! : () => Bool
removing_before_a_reference_shifts_its_index! = || {
	one = Todo.submit_draft({ ..Todo.initial, draft: "one" })
	two = Todo.submit_draft({ ..one, draft: "two" })
	three = Todo.submit_draft({ ..two, draft: "three" })
	selection = LineEditing.selection_at_end("three")
	editing = Todo.start_edit(three, 2, selection)
	shifted_editor = Todo.remove(editing, 0)
	focused = Todo.focus_target(three, EditButton(2))
	shifted_target = Todo.remove(focused, 0)
	task_matches_at(shifted_editor.tasks, 1, "three", Bool.False)
		and Todo.is_editing(shifted_editor, 1)
			and task_edit_focus_matches(shifted_editor.focus, 1, selection)
				and target_focus_matches(shifted_target.focus, EditButton(1))
}

empty_submission_preserves_draft_and_focus! : () => Bool
empty_submission_preserves_draft_and_focus! = || {
	selection = LineEditing.selection_at_end("   ")
	model = Todo.change_draft(Todo.initial, "   ", selection)
	next = Todo.submit_draft(model)
	focus_preserved = draft_focus_matches(next.focus, selection)
	blurred = Todo.clear_focus(next)
	next.draft == "   " and List.is_empty(next.tasks) and focus_preserved and no_focus(blurred.focus)
}

losing_task_edit_focus_commits_nonempty_text! : () => Bool
losing_task_edit_focus_commits_nonempty_text! = || {
	added = Todo.submit_draft({ ..Todo.initial, draft: "one" })
	editing = Todo.start_edit(added, 0, LineEditing.selection_at_end("one"))
	changed = Todo.change_label(editing, 0, "  renamed  ", LineEditing.selection_at_end("  renamed  "))
	blurred = Todo.clear_focus(changed)
	task_matches_at(blurred.tasks, 0, "renamed", Bool.False)
		and !(Todo.is_editing(blurred, 0))
			and no_focus(blurred.focus)
}

losing_task_edit_focus_can_delete_and_remap_the_destination! : () => Bool
losing_task_edit_focus_can_delete_and_remap_the_destination! = || {
	one = Todo.submit_draft({ ..Todo.initial, draft: "one" })
	two = Todo.submit_draft({ ..one, draft: "two" })
	editing = Todo.start_edit(two, 0, LineEditing.empty_selection)
	emptied = Todo.change_label(editing, 0, "", LineEditing.empty_selection)
	blurred = Todo.focus_target(emptied, TaskCheckbox(1))
	List.len(blurred.tasks) == 1
		and task_matches_at(blurred.tasks, 0, "two", Bool.False)
			and Todo.target_focused(blurred, TaskCheckbox(0))
}

move_focus! : Todo.Model, Bool => Todo.Model
move_focus! = |model, backwards| {
	tab = {
		timestamp_nanos: 0,
		key: Named(Tab),
		state: KeyDown,
		modifiers: { ..Event.empty_modifiers, shift: backwards },
	}
	description = { order: TodoFocus.order(model), clear!: |state| Todo.clear_focus(state) }
	match Handler.dispatch!(KeyboardFocus.handler(description), model, Key(tab)) {
		Handled(next) => next
		Declined => model
	}
}

todo_owns_focus_order! : () => Bool
todo_owns_focus_order! = || {
	first = move_focus!(Todo.initial, Bool.False)
	last = move_focus!(Todo.initial, Bool.True)
	added = Todo.submit_draft({ ..Todo.initial, draft: "one" })
	from_draft = move_focus!(Todo.focus_draft(added, LineEditing.empty_selection), Bool.False)
	from_add = move_focus!(from_draft, Bool.False)
	from_toggle = move_focus!(from_add, Bool.False)
	from_edit = move_focus!(from_toggle, Bool.False)
	wrapped = move_focus!(from_edit, Bool.False)
	draft_focused_at_start(first.focus)
		and target_focus_matches(last.focus, AddButton)
			and target_focus_matches(from_draft.focus, AddButton)
				and target_focus_matches(from_add.focus, TaskCheckbox(0))
					and target_focus_matches(from_toggle.focus, EditButton(0))
						and target_focus_matches(from_edit.focus, DeleteButton(0))
							and draft_focused_at_start(wrapped.focus)
}

editing_adds_its_editor_to_the_app_order! : () => Bool
editing_adds_its_editor_to_the_app_order! = || {
	added = Todo.submit_draft({ ..Todo.initial, draft: "one" })
	editing = Todo.start_edit(added, 0, LineEditing.empty_selection)
	edit_button = move_focus!(editing, Bool.False)
	backwards = move_focus!(edit_button, Bool.True)
	target_focus_matches(edit_button.focus, EditButton(0))
		and !(Todo.is_editing(edit_button, 0))
			and target_focus_matches(backwards.focus, TaskCheckbox(0))
}

tab_is_an_ordinary_app_event! : () => Bool
tab_is_an_ordinary_app_event! = || {
	tab = { timestamp_nanos: 0, key: Named(Tab), state: KeyDown, modifiers: Event.empty_modifiers }
	shift_tab = { ..tab, modifiers: { ..Event.empty_modifiers, shift: Bool.True } }
	ctrl_tab = { ..tab, modifiers: { ..Event.empty_modifiers, ctrl: Bool.True } }
	handler = KeyboardFocus.handler({ order: TodoFocus.order(Todo.initial), clear!: |state| Todo.clear_focus(state) })
	forward = Handler.dispatch!(handler, Todo.initial, Key(tab))
	backward = Handler.dispatch!(handler, Todo.initial, Key(shift_tab))
	modified = Handler.dispatch!(handler, Todo.initial, Key(ctrl_tab))
	forward_matches = match forward {
		Handled(model) => draft_focused_at_start(model.focus)
		Declined => Bool.False
	}
	backward_matches = match backward {
		Handled(model) => target_focus_matches(model.focus, AddButton)
		Declined => Bool.False
	}
	forward_matches and backward_matches and modified == Declined
}

drag_preview_matches : Reorder.State, U64, U64, Geometry2d.Point(F32), Geometry2d.Size(F32) -> Bool
drag_preview_matches = |drag, source_index, gap_index, grab_offset, size| match drag {
	Dragging(preview) => preview.source_index == source_index and preview.gap_index == gap_index and preview.grab_offset == grab_offset and preview.size == size
	Idle | Armed(_) => Bool.False
}

drag_is_idle : Reorder.State -> Bool
drag_is_idle = |drag| match drag {
	Idle => Bool.True
	Armed(_) | Dragging(_) => Bool.False
}

drag_preview_is_ephemeral_until_drop! : () => Bool
drag_preview_is_ephemeral_until_drop! = || {
	one = Todo.submit_draft({ ..Todo.initial, draft: "one" })
	two = Todo.submit_draft({ ..one, draft: "two" })
	three = Todo.submit_draft({ ..two, draft: "three" })
	selection = LineEditing.selection_at_end("three")
	model = Todo.start_edit(three, 2, selection)

	armed = Todo.set_drag(model, Reorder.arm(1))
	active = Reorder.activate(
		armed.drag,
		Geometry2d.rect(10, 20, 200, 50),
		Geometry2d.point(18, 33),
	)
	previewed = Todo.set_drag(armed, Reorder.set_gap(active, 0))
	committed = Todo.set_drag(Todo.reorder(previewed, 1, 0), Reorder.idle)

	preview_matches = drag_preview_matches(
		previewed.drag,
		1,
		0,
		Geometry2d.point(8, 13),
		Geometry2d.size(200, 50),
	)
	preview_tasks_unchanged = task_matches_at(previewed.tasks, 0, "one", Bool.False)
		and task_matches_at(previewed.tasks, 1, "two", Bool.False)
			and task_matches_at(previewed.tasks, 2, "three", Bool.False)
	committed_order = task_matches_at(committed.tasks, 0, "two", Bool.False)
		and task_matches_at(committed.tasks, 1, "one", Bool.False)
			and task_matches_at(committed.tasks, 2, "three", Bool.False)
	not_dragging = drag_is_idle(committed.drag)
	preview_matches
		and preview_tasks_unchanged
			and committed_order
				and not_dragging
					and Todo.is_editing(committed, 2)
						and task_edit_focus_matches(committed.focus, 2, selection)
}

main! = || if submit_trims_and_appends_tasks!() and indices_distinguish_identical_tasks!() and add_focus_is_distinct!() and editing_changes_label_and_finishes_on_edit_button!() and committing_empty_edit_removes_task!() and cancelling_edit_restores_original_label!() and removing_edited_task_clears_editing!() and removing_before_a_reference_shifts_its_index!() and empty_submission_preserves_draft_and_focus!() and losing_task_edit_focus_commits_nonempty_text!() and losing_task_edit_focus_can_delete_and_remap_the_destination!() and todo_owns_focus_order!() and editing_adds_its_editor_to_the_app_order!() and tab_is_an_ordinary_app_event!() and drag_preview_is_ephemeral_until_drop!() 0 else 1
