## Public pure state transitions for a single-line editor. UTF-8 storage
## mechanics and word classification live in package-private modules.
import Event
import LineEditingInternal

LineEditing := [].{
	TextRange : LineEditingInternal.TextRange
	Drag : LineEditingInternal.Drag
	SelectionState : LineEditingInternal.SelectionState
	Update : LineEditingInternal.Update
	EditResult : LineEditingInternal.EditResult

	empty_selection : SelectionState
	empty_selection = LineEditingInternal.empty_selection

	selection_at_end : Str -> SelectionState
	selection_at_end = |text| LineEditingInternal.selection_at_end(text)

	is_dragging : SelectionState -> Bool
	is_dragging = |selection| LineEditingInternal.is_dragging(selection)

	clamp_selection : Str, SelectionState -> SelectionState
	clamp_selection = |text, selection| LineEditingInternal.clamp_selection(text, selection)

	selection_range : Str, SelectionState -> TextRange
	selection_range = |text, selection| LineEditingInternal.selection_range(text, selection)

	replace_selection : Str, Str, SelectionState -> Update
	replace_selection = |text, inserted, selection| LineEditingInternal.replace_selection(text, inserted, selection)

	selected_text : Str, SelectionState -> [Some(Str), None]
	selected_text = |text, selection| LineEditingInternal.selected_text(text, selection)

	delete_backward : Str, SelectionState -> Update
	delete_backward = |text, selection| LineEditingInternal.delete_backward(text, selection)

	delete_forward : Str, SelectionState -> Update
	delete_forward = |text, selection| LineEditingInternal.delete_forward(text, selection)

	word_range : Str, U64 -> TextRange
	word_range = |text, requested| LineEditingInternal.word_range(text, requested)

	previous_word_boundary : Str, U64 -> U64
	previous_word_boundary = |text, requested| LineEditingInternal.previous_word_boundary(text, requested)

	next_word_boundary : Str, U64 -> U64
	next_word_boundary = |text, requested| LineEditingInternal.next_word_boundary(text, requested)

	move_focus : Str, SelectionState, [Backward, Forward], Bool -> SelectionState
	move_focus = |text, selection, direction, extend| LineEditingInternal.move_focus(text, selection, direction, extend)

	move_word : Str, SelectionState, [Backward, Forward], Bool -> SelectionState
	move_word = |text, selection, direction, extend| LineEditingInternal.move_word(text, selection, direction, extend)

	move_home : SelectionState, Bool -> SelectionState
	move_home = |selection, extend| LineEditingInternal.move_home(selection, extend)

	move_end : Str, SelectionState, Bool -> SelectionState
	move_end = |text, selection, extend| LineEditingInternal.move_end(text, selection, extend)

	select_all : Str -> SelectionState
	select_all = |text| LineEditingInternal.select_all(text)

	delete_word_backward : Str, SelectionState -> Update
	delete_word_backward = |text, selection| LineEditingInternal.delete_word_backward(text, selection)

	delete_word_forward : Str, SelectionState -> Update
	delete_word_forward = |text, selection| LineEditingInternal.delete_word_forward(text, selection)

	delete_to_start : Str, SelectionState -> Update
	delete_to_start = |text, selection| LineEditingInternal.delete_to_start(text, selection)

	delete_to_end : Str, SelectionState -> Update
	delete_to_end = |text, selection| LineEditingInternal.delete_to_end(text, selection)

	start_pointer_selection : Str, SelectionState, U64, U8, Bool -> SelectionState
	start_pointer_selection = |text, selection, requested, clicks, extend| LineEditingInternal.start_pointer_selection(text, selection, requested, clicks, extend)

	continue_drag : Str, SelectionState, U64 -> SelectionState
	continue_drag = |text, selection, requested| LineEditingInternal.continue_drag(text, selection, requested)

	end_drag : SelectionState -> SelectionState
	end_drag = |selection| LineEditingInternal.end_drag(selection)

	handle_key : Str, SelectionState, Event.KeyEvent -> EditResult
	handle_key = |text, selection, event| LineEditingInternal.handle_key(text, selection, event)
}
