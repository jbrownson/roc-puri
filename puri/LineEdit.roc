## Public pure state transitions for a single-line editor. UTF-8 storage
## mechanics and word classification live in package-private modules.
import Event
import LineEditInternal

LineEdit := [].{
	TextRange : LineEditInternal.TextRange
	Drag : LineEditInternal.Drag
	SelectionState : LineEditInternal.SelectionState
	Update : LineEditInternal.Update
	EditResult : LineEditInternal.EditResult

	empty_selection : SelectionState
	empty_selection = LineEditInternal.empty_selection

	selection_at_end : Str -> SelectionState
	selection_at_end = |text| LineEditInternal.selection_at_end(text)

	is_dragging : SelectionState -> Bool
	is_dragging = |selection| LineEditInternal.is_dragging(selection)

	clamp_selection : Str, SelectionState -> SelectionState
	clamp_selection = |text, selection| LineEditInternal.clamp_selection(text, selection)

	selection_range : Str, SelectionState -> TextRange
	selection_range = |text, selection| LineEditInternal.selection_range(text, selection)

	replace_selection : Str, Str, SelectionState -> Update
	replace_selection = |text, inserted, selection| LineEditInternal.replace_selection(text, inserted, selection)

	selected_text : Str, SelectionState -> [Some(Str), None]
	selected_text = |text, selection| LineEditInternal.selected_text(text, selection)

	delete_backward : Str, SelectionState -> Update
	delete_backward = |text, selection| LineEditInternal.delete_backward(text, selection)

	delete_forward : Str, SelectionState -> Update
	delete_forward = |text, selection| LineEditInternal.delete_forward(text, selection)

	word_range : Str, U64 -> TextRange
	word_range = |text, requested| LineEditInternal.word_range(text, requested)

	previous_word_boundary : Str, U64 -> U64
	previous_word_boundary = |text, requested| LineEditInternal.previous_word_boundary(text, requested)

	next_word_boundary : Str, U64 -> U64
	next_word_boundary = |text, requested| LineEditInternal.next_word_boundary(text, requested)

	move_focus : Str, SelectionState, [Backward, Forward], Bool -> SelectionState
	move_focus = |text, selection, direction, extend| LineEditInternal.move_focus(text, selection, direction, extend)

	move_word : Str, SelectionState, [Backward, Forward], Bool -> SelectionState
	move_word = |text, selection, direction, extend| LineEditInternal.move_word(text, selection, direction, extend)

	move_home : SelectionState, Bool -> SelectionState
	move_home = |selection, extend| LineEditInternal.move_home(selection, extend)

	move_end : Str, SelectionState, Bool -> SelectionState
	move_end = |text, selection, extend| LineEditInternal.move_end(text, selection, extend)

	select_all : Str -> SelectionState
	select_all = |text| LineEditInternal.select_all(text)

	delete_word_backward : Str, SelectionState -> Update
	delete_word_backward = |text, selection| LineEditInternal.delete_word_backward(text, selection)

	delete_word_forward : Str, SelectionState -> Update
	delete_word_forward = |text, selection| LineEditInternal.delete_word_forward(text, selection)

	delete_to_start : Str, SelectionState -> Update
	delete_to_start = |text, selection| LineEditInternal.delete_to_start(text, selection)

	delete_to_end : Str, SelectionState -> Update
	delete_to_end = |text, selection| LineEditInternal.delete_to_end(text, selection)

	start_pointer_selection : Str, SelectionState, U64, U8, Bool -> SelectionState
	start_pointer_selection = |text, selection, requested, clicks, extend| LineEditInternal.start_pointer_selection(text, selection, requested, clicks, extend)

	continue_drag : Str, SelectionState, U64 -> SelectionState
	continue_drag = |text, selection, requested| LineEditInternal.continue_drag(text, selection, requested)

	end_drag : SelectionState -> SelectionState
	end_drag = |selection| LineEditInternal.end_drag(selection)

	handle_key : Str, SelectionState, Event.KeyEvent -> EditResult
	handle_key = |text, selection, event| LineEditInternal.handle_key(text, selection, event)
}
