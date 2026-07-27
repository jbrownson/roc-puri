## Public pure state transitions for a single-line editor. UTF-8 scanning and
## word-classification helpers live in the package-private implementation.
import Event
import LineEditInternal

LineEdit := [].{
	SelectionBounds : LineEditInternal.SelectionBounds
	Drag : LineEditInternal.Drag
	LineEditSelection : LineEditInternal.LineEditSelection
	Edit : LineEditInternal.Edit
	EditResult : LineEditInternal.EditResult

	empty_selection : LineEditSelection
	empty_selection = LineEditInternal.empty_selection

	selection_at_end : Str -> LineEditSelection
	selection_at_end = |text| LineEditInternal.selection_at_end(text)

	is_dragging : LineEditSelection -> Bool
	is_dragging = |selection| LineEditInternal.is_dragging(selection)

	next_boundary : List(U8), U64 -> U64
	next_boundary = |bytes, requested| LineEditInternal.next_boundary(bytes, requested)

	clamp_selection : Str, LineEditSelection -> LineEditSelection
	clamp_selection = |text, selection| LineEditInternal.clamp_selection(text, selection)

	selection_bounds : Str, LineEditSelection -> SelectionBounds
	selection_bounds = |text, selection| LineEditInternal.selection_bounds(text, selection)

	prefix : Str, U64 -> Str
	prefix = |text, end| LineEditInternal.prefix(text, end)

	slice : Str, U64, U64 -> Str
	slice = |text, start, end| LineEditInternal.slice(text, start, end)

	replace_selection : Str, Str, LineEditSelection -> Edit
	replace_selection = |text, inserted, selection| LineEditInternal.replace_selection(text, inserted, selection)

	selected_text : Str, LineEditSelection -> [Some(Str), None]
	selected_text = |text, selection| LineEditInternal.selected_text(text, selection)

	delete_backward : Str, LineEditSelection -> Edit
	delete_backward = |text, selection| LineEditInternal.delete_backward(text, selection)

	delete_forward : Str, LineEditSelection -> Edit
	delete_forward = |text, selection| LineEditInternal.delete_forward(text, selection)

	word_bounds : Str, U64 -> SelectionBounds
	word_bounds = |text, requested| LineEditInternal.word_bounds(text, requested)

	previous_word_boundary : Str, U64 -> U64
	previous_word_boundary = |text, requested| LineEditInternal.previous_word_boundary(text, requested)

	next_word_boundary : Str, U64 -> U64
	next_word_boundary = |text, requested| LineEditInternal.next_word_boundary(text, requested)

	move_focus : Str, LineEditSelection, [Backward, Forward], Bool -> LineEditSelection
	move_focus = |text, selection, direction, extend| LineEditInternal.move_focus(text, selection, direction, extend)

	move_word : Str, LineEditSelection, [Backward, Forward], Bool -> LineEditSelection
	move_word = |text, selection, direction, extend| LineEditInternal.move_word(text, selection, direction, extend)

	move_home : LineEditSelection, Bool -> LineEditSelection
	move_home = |selection, extend| LineEditInternal.move_home(selection, extend)

	move_end : Str, LineEditSelection, Bool -> LineEditSelection
	move_end = |text, selection, extend| LineEditInternal.move_end(text, selection, extend)

	select_all : Str -> LineEditSelection
	select_all = |text| LineEditInternal.select_all(text)

	delete_word_backward : Str, LineEditSelection -> Edit
	delete_word_backward = |text, selection| LineEditInternal.delete_word_backward(text, selection)

	delete_word_forward : Str, LineEditSelection -> Edit
	delete_word_forward = |text, selection| LineEditInternal.delete_word_forward(text, selection)

	delete_to_start : Str, LineEditSelection -> Edit
	delete_to_start = |text, selection| LineEditInternal.delete_to_start(text, selection)

	delete_to_end : Str, LineEditSelection -> Edit
	delete_to_end = |text, selection| LineEditInternal.delete_to_end(text, selection)

	start_pointer_selection : Str, LineEditSelection, U64, U8, Bool -> LineEditSelection
	start_pointer_selection = |text, selection, requested, clicks, extend| LineEditInternal.start_pointer_selection(text, selection, requested, clicks, extend)

	continue_drag : Str, LineEditSelection, U64 -> LineEditSelection
	continue_drag = |text, selection, requested| LineEditInternal.continue_drag(text, selection, requested)

	end_drag : LineEditSelection -> LineEditSelection
	end_drag = |selection| LineEditInternal.end_drag(selection)

	handle_key : Str, LineEditSelection, Event.KeyEvent -> EditResult
	handle_key = |text, selection, event| LineEditInternal.handle_key(text, selection, event)
}
