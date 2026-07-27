## Pure single-line editing transitions.
##
## A SelectionState contains only interaction facts. Text is supplied
## independently for each transition, so neither this module nor a Puri widget
## dictates how an application normalizes or stores its model. Offsets are
## UTF-8 byte boundaries and are clamped against the supplied text wherever
## read.
import Event
import Utf8

LineEditingInternal := [].{

	## A normalized half-open UTF-8 byte range.
	TextRange : {
		start : U64,
		end : U64,
	}

	Drag := [CharacterDrag, WordDrag({ origin : TextRange }), AllDrag, NotDragging]

	## App-owned selection and pointer-drag state.
	SelectionState : {
		anchor : U64,
		focus : U64,
		drag : Drag,
	}

	Update : {
		text : Str,
		selection : SelectionState,
	}

	EditResult := [Updated(Update), Copy(Str), Cut({ copied : Str, update : Update }), Paste, Ignored]

	empty_selection : SelectionState
	empty_selection = { anchor: 0, focus: 0, drag: NotDragging }

	selection_at_end : Str -> SelectionState
	selection_at_end = |text| {
		end = Str.count_utf8_bytes(text)
		{ anchor: end, focus: end, drag: NotDragging }
	}

	is_dragging : SelectionState -> Bool
	is_dragging = |selection| match selection.drag {
		NotDragging => Bool.False
		_ => Bool.True
	}

	# Selection normalization and basic editing.

	clamp_selection : Str, SelectionState -> SelectionState
	clamp_selection = |text, selection| {
		bytes = Str.to_utf8(text)
		{
			..selection,
			anchor: Utf8.boundary_at_or_before(bytes, selection.anchor),
			focus: Utf8.boundary_at_or_before(bytes, selection.focus),
		}
	}

	selection_range : Str, SelectionState -> TextRange
	selection_range = |text, source| {
		selection = LineEditingInternal.clamp_selection(text, source)
		{
			start: U64.min(selection.anchor, selection.focus),
			end: U64.max(selection.anchor, selection.focus),
		}
	}

	replace_selection : Str, Str, SelectionState -> Update
	replace_selection = |text, inserted, source| {
		selection = LineEditingInternal.clamp_selection(text, source)
		range = LineEditingInternal.selection_range(text, selection)
		next_text = Utf8.replace_range(text, range.start, range.end, inserted)
		caret = range.start + Str.count_utf8_bytes(inserted)
		{
			text: next_text,
			selection: { anchor: caret, focus: caret, drag: NotDragging },
		}
	}

	selected_text : Str, SelectionState -> [Some(Str), None]
	selected_text = |text, selection| {
		range = LineEditingInternal.selection_range(text, selection)
		if range.start == range.end None else Some(Utf8.slice(text, range.start, range.end))
	}

	delete_backward : Str, SelectionState -> Update
	delete_backward = |text, source| {
		selection = LineEditingInternal.clamp_selection(text, source)
		range = LineEditingInternal.selection_range(text, selection)
		if range.start != range.end {
			LineEditingInternal.replace_selection(text, "", selection)
		} else if range.start == 0 {
			{ text, selection: { ..selection, anchor: 0, focus: 0, drag: NotDragging } }
		} else {
			bytes = Str.to_utf8(text)
			start = Utf8.previous_boundary(bytes, range.start)
			next_text = Utf8.replace_range(text, start, range.start, "")
			{ text: next_text, selection: { anchor: start, focus: start, drag: NotDragging } }
		}
	}

	delete_forward : Str, SelectionState -> Update
	delete_forward = |text, source| {
		selection = LineEditingInternal.clamp_selection(text, source)
		range = LineEditingInternal.selection_range(text, selection)
		if range.start != range.end {
			LineEditingInternal.replace_selection(text, "", selection)
		} else {
			bytes = Str.to_utf8(text)
			end = Utf8.next_boundary(bytes, range.end)
			next_text = Utf8.replace_range(text, range.end, end, "")
			{ text: next_text, selection: { anchor: range.end, focus: range.end, drag: NotDragging } }
		}
	}

	# Word selection, movement, and deletion.

	ByteClass := [WordByte, SpaceByte, PunctuationByte]

	byte_class : U8 -> ByteClass
	byte_class = |byte| if byte >= 128 or byte >= 48 and byte <= 57 or byte >= 65 and byte <= 90 or byte >= 97 and byte <= 122 or byte == 95 {
		WordByte
	} else if byte <= 32 {
		SpaceByte
	} else {
		PunctuationByte
	}

	class_at : List(U8), U64 -> ByteClass
	class_at = |bytes, index| match List.get(bytes, index) {
		Ok(byte) => LineEditingInternal.byte_class(byte)
		Err(_) => SpaceByte
	}

	same_class : ByteClass, ByteClass -> Bool
	same_class = |left, right| match (left, right) {
		(WordByte, WordByte) => Bool.True
		(SpaceByte, SpaceByte) => Bool.True
		(PunctuationByte, PunctuationByte) => Bool.True
		_ => Bool.False
	}

	scan_class_backward : List(U8), U64, ByteClass -> U64
	scan_class_backward = |bytes, index, class| if index == 0 {
		0
	} else {
		previous = Utf8.previous_boundary(bytes, index)
		if LineEditingInternal.same_class(LineEditingInternal.class_at(bytes, previous), class) {
			LineEditingInternal.scan_class_backward(bytes, previous, class)
		} else {
			index
		}
	}

	scan_class_forward : List(U8), U64, ByteClass -> U64
	scan_class_forward = |bytes, index, class| if index >= List.len(bytes) {
		List.len(bytes)
	} else if LineEditingInternal.same_class(LineEditingInternal.class_at(bytes, index), class) {
		LineEditingInternal.scan_class_forward(bytes, Utf8.next_boundary(bytes, index), class)
	} else {
		index
	}

	word_range : Str, U64 -> TextRange
	word_range = |text, requested| {
		bytes = Str.to_utf8(text)
		length = List.len(bytes)
		index = if requested >= length and length > 0 {
			Utf8.previous_boundary(bytes, length)
		} else {
			Utf8.boundary_at_or_before(bytes, requested)
		}
		class = LineEditingInternal.class_at(bytes, index)
		{
			start: LineEditingInternal.scan_class_backward(bytes, index, class),
			end: LineEditingInternal.scan_class_forward(bytes, index, class),
		}
	}

	previous_word_boundary_from : List(U8), U64 -> U64
	previous_word_boundary_from = |bytes, index| if index == 0 {
		0
	} else {
		previous = Utf8.previous_boundary(bytes, index)
		if LineEditingInternal.same_class(LineEditingInternal.class_at(bytes, previous), WordByte) {
			LineEditingInternal.scan_class_backward(bytes, index, WordByte)
		} else {
			LineEditingInternal.previous_word_boundary_from(bytes, previous)
		}
	}

	previous_word_boundary : Str, U64 -> U64
	previous_word_boundary = |text, requested| {
		bytes = Str.to_utf8(text)
		LineEditingInternal.previous_word_boundary_from(bytes, Utf8.boundary_at_or_before(bytes, requested))
	}

	next_word_boundary_from : List(U8), U64 -> U64
	next_word_boundary_from = |bytes, index| if index >= List.len(bytes) {
		List.len(bytes)
	} else if LineEditingInternal.same_class(LineEditingInternal.class_at(bytes, index), WordByte) {
		LineEditingInternal.scan_class_forward(bytes, index, WordByte)
	} else {
		LineEditingInternal.next_word_boundary_from(bytes, Utf8.next_boundary(bytes, index))
	}

	next_word_boundary : Str, U64 -> U64
	next_word_boundary = |text, requested| {
		bytes = Str.to_utf8(text)
		LineEditingInternal.next_word_boundary_from(bytes, Utf8.boundary_at_or_before(bytes, requested))
	}

	move_focus : Str, SelectionState, [Backward, Forward], Bool -> SelectionState
	move_focus = |text, source, direction, extend| {
		selection = LineEditingInternal.clamp_selection(text, source)
		bytes = Str.to_utf8(text)
		range = LineEditingInternal.selection_range(text, selection)
		moved = if !extend and range.start != range.end {
			match direction {
				Backward => range.start
				Forward => range.end
			}
		} else match direction {
			Backward => Utf8.previous_boundary(bytes, selection.focus)
			Forward => Utf8.next_boundary(bytes, selection.focus)
		}
		{
			..selection,
			anchor: if extend selection.anchor else moved,
			focus: moved,
			drag: NotDragging,
		}
	}

	move_word : Str, SelectionState, [Backward, Forward], Bool -> SelectionState
	move_word = |text, source, direction, extend| {
		selection = LineEditingInternal.clamp_selection(text, source)
		range = LineEditingInternal.selection_range(text, selection)
		moved = if !extend and range.start != range.end {
			match direction {
				Backward => range.start
				Forward => range.end
			}
		} else match direction {
			Backward => LineEditingInternal.previous_word_boundary(text, selection.focus)
			Forward => LineEditingInternal.next_word_boundary(text, selection.focus)
		}
		{
			..selection,
			anchor: if extend selection.anchor else moved,
			focus: moved,
			drag: NotDragging,
		}
	}

	move_home : SelectionState, Bool -> SelectionState
	move_home = |selection, extend| {
		{ ..selection, anchor: if extend selection.anchor else 0, focus: 0, drag: NotDragging }
	}

	move_end : Str, SelectionState, Bool -> SelectionState
	move_end = |text, source, extend| {
		selection = LineEditingInternal.clamp_selection(text, source)
		end = Str.count_utf8_bytes(text)
		{ ..selection, anchor: if extend selection.anchor else end, focus: end, drag: NotDragging }
	}

	select_all : Str -> SelectionState
	select_all = |text| { anchor: 0, focus: Str.count_utf8_bytes(text), drag: NotDragging }

	delete_word_backward : Str, SelectionState -> Update
	delete_word_backward = |text, source| {
		selection = LineEditingInternal.clamp_selection(text, source)
		range = LineEditingInternal.selection_range(text, selection)
		if range.start != range.end {
			LineEditingInternal.replace_selection(text, "", selection)
		} else {
			start = LineEditingInternal.previous_word_boundary(text, range.start)
			next_text = Utf8.replace_range(text, start, range.start, "")
			{ text: next_text, selection: { anchor: start, focus: start, drag: NotDragging } }
		}
	}

	delete_word_forward : Str, SelectionState -> Update
	delete_word_forward = |text, source| {
		selection = LineEditingInternal.clamp_selection(text, source)
		range = LineEditingInternal.selection_range(text, selection)
		if range.start != range.end {
			LineEditingInternal.replace_selection(text, "", selection)
		} else {
			end = LineEditingInternal.next_word_boundary(text, range.end)
			next_text = Utf8.replace_range(text, range.end, end, "")
			{ text: next_text, selection: { anchor: range.end, focus: range.end, drag: NotDragging } }
		}
	}

	delete_to_start : Str, SelectionState -> Update
	delete_to_start = |text, source| {
		selection = LineEditingInternal.clamp_selection(text, source)
		range = LineEditingInternal.selection_range(text, selection)
		if range.start != range.end {
			LineEditingInternal.replace_selection(text, "", selection)
		} else {
			next_text = Utf8.replace_range(text, 0, range.start, "")
			{ text: next_text, selection: LineEditingInternal.empty_selection }
		}
	}

	delete_to_end : Str, SelectionState -> Update
	delete_to_end = |text, source| {
		selection = LineEditingInternal.clamp_selection(text, source)
		range = LineEditingInternal.selection_range(text, selection)
		if range.start != range.end {
			LineEditingInternal.replace_selection(text, "", selection)
		} else {
			next_text = Utf8.replace_range(text, range.end, Str.count_utf8_bytes(text), "")
			{ text: next_text, selection: { anchor: range.end, focus: range.end, drag: NotDragging } }
		}
	}

	# Pointer-driven selection.

	start_pointer_selection : Str, SelectionState, U64, U8, Bool -> SelectionState
	start_pointer_selection = |text, source, requested, clicks, extend| if clicks >= 3 {
		{ anchor: 0, focus: Str.count_utf8_bytes(text), drag: AllDrag }
	} else if clicks == 2 {
		range = LineEditingInternal.word_range(text, requested)
		{ anchor: range.start, focus: range.end, drag: WordDrag({ origin: range }) }
	} else {
		index = Utf8.boundary_at_or_before(Str.to_utf8(text), requested)
		selection = LineEditingInternal.clamp_selection(text, source)
		{ anchor: if extend selection.anchor else index, focus: index, drag: CharacterDrag }
	}

	continue_drag : Str, SelectionState, U64 -> SelectionState
	continue_drag = |text, source, requested| {
		selection = LineEditingInternal.clamp_selection(text, source)
		index = Utf8.boundary_at_or_before(Str.to_utf8(text), requested)
		match selection.drag {
			CharacterDrag => { ..selection, focus: index }
			WordDrag({ origin }) => {
				target = LineEditingInternal.word_range(text, index)
				if target.end <= origin.start {
					{ ..selection, anchor: origin.end, focus: target.start }
				} else if target.start >= origin.end {
					{ ..selection, anchor: origin.start, focus: target.end }
				} else {
					{ ..selection, anchor: origin.start, focus: origin.end }
				}
			}
			AllDrag => selection
			NotDragging => selection
		}
	}

	end_drag : SelectionState -> SelectionState
	end_drag = |selection| { ..selection, drag: NotDragging }

	# Desktop single-line key bindings.

	handle_key : Str, SelectionState, Event.KeyEvent -> EditResult
	handle_key = |text, selection, event| match event.state {
		KeyUp => Ignored
		KeyDown => match event.key {
			Character(string) if (event.modifiers.meta or event.modifiers.ctrl) and Str.caseless_ascii_equals(string, "a") => Updated({ text, selection: LineEditingInternal.select_all(text) })
			Character(string) if (event.modifiers.meta or event.modifiers.ctrl) and Str.caseless_ascii_equals(string, "c") => match LineEditingInternal.selected_text(text, selection) {
				Some(selected) => Copy(selected)
				None => Ignored
			}
			Character(string) if (event.modifiers.meta or event.modifiers.ctrl) and Str.caseless_ascii_equals(string, "x") => match LineEditingInternal.selected_text(text, selection) {
				Some(selected) => Cut({ copied: selected, update: LineEditingInternal.replace_selection(text, "", selection) })
				None => Ignored
			}
			Character(string) if (event.modifiers.meta or event.modifiers.ctrl) and Str.caseless_ascii_equals(string, "v") => Paste
			Character(string) => if event.modifiers.ctrl or event.modifiers.meta {
				Ignored
			} else {
				Updated(LineEditingInternal.replace_selection(text, string, selection))
			}
			Named(Backspace) => if event.modifiers.meta {
				Updated(LineEditingInternal.delete_to_start(text, selection))
			} else if event.modifiers.alt or event.modifiers.ctrl {
				Updated(LineEditingInternal.delete_word_backward(text, selection))
			} else {
				Updated(LineEditingInternal.delete_backward(text, selection))
			}
			Named(Delete) => if event.modifiers.meta {
				Updated(LineEditingInternal.delete_to_end(text, selection))
			} else if event.modifiers.alt or event.modifiers.ctrl {
				Updated(LineEditingInternal.delete_word_forward(text, selection))
			} else {
				Updated(LineEditingInternal.delete_forward(text, selection))
			}
			Named(ArrowLeft) => if event.modifiers.meta {
				Updated({ text, selection: LineEditingInternal.move_home(selection, event.modifiers.shift) })
			} else if event.modifiers.alt or event.modifiers.ctrl {
				Updated({ text, selection: LineEditingInternal.move_word(text, selection, Backward, event.modifiers.shift) })
			} else {
				Updated({ text, selection: LineEditingInternal.move_focus(text, selection, Backward, event.modifiers.shift) })
			}
			Named(ArrowRight) => if event.modifiers.meta {
				Updated({ text, selection: LineEditingInternal.move_end(text, selection, event.modifiers.shift) })
			} else if event.modifiers.alt or event.modifiers.ctrl {
				Updated({ text, selection: LineEditingInternal.move_word(text, selection, Forward, event.modifiers.shift) })
			} else {
				Updated({ text, selection: LineEditingInternal.move_focus(text, selection, Forward, event.modifiers.shift) })
			}
			Named(Home) => Updated({ text, selection: LineEditingInternal.move_home(selection, event.modifiers.shift) })
			Named(End) => Updated({ text, selection: LineEditingInternal.move_end(text, selection, event.modifiers.shift) })
			Named(Space) => if event.modifiers.ctrl or event.modifiers.meta Ignored else Updated(LineEditingInternal.replace_selection(text, " ", selection))
			_ => Ignored
		}
	}
}

expect {
	selection = LineEditingInternal.selection_at_end("hi")
	event = { key: Character("!"), state: KeyDown, modifiers: Event.empty_modifiers }
	match LineEditingInternal.handle_key("hi", selection, event) {
		Updated(update) => update.text == "hi!" and update.selection.anchor == 3 and update.selection.focus == 3
		_ => Bool.False
	}
}

expect {
	first = LineEditingInternal.delete_backward("a🐦b", LineEditingInternal.selection_at_end("a🐦b"))
	second = LineEditingInternal.delete_backward(first.text, first.selection)
	first.text == "a🐦" and first.selection.focus == 5 and second.text == "a" and second.selection.focus == 1
}

expect {
	selection = { anchor: 1, focus: 4, drag: NotDragging }
	replaced = LineEditingInternal.replace_selection("hello", "i", selection)
	replaced.text == "hio" and replaced.selection.anchor == 2 and replaced.selection.focus == 2 and !(LineEditingInternal.is_dragging(replaced.selection))
}

expect {
	selection = { anchor: 1, focus: 4, drag: NotDragging }
	left = LineEditingInternal.move_focus("hello", selection, Backward, Bool.False)
	right = LineEditingInternal.move_focus("hello", selection, Forward, Bool.False)
	left.anchor == 1 and left.focus == 1 and right.anchor == 4 and right.focus == 4
}

expect {
	text = "one, two  three"
	range = LineEditingInternal.word_range(text, 6)
	backward = LineEditingInternal.move_word(text, { anchor: 15, focus: 15, drag: NotDragging }, Backward, Bool.False)
	forward = LineEditingInternal.move_word(text, LineEditingInternal.empty_selection, Forward, Bool.False)
	range.start == 5 and range.end == 8 and backward.focus == 10 and forward.focus == 3
}

expect {
	text = "one, two"
	backward = LineEditingInternal.delete_word_backward(text, LineEditingInternal.selection_at_end(text))
	forward = LineEditingInternal.delete_word_forward(text, LineEditingInternal.empty_selection)
	backward.text == "one, " and backward.selection.focus == 5 and forward.text == ", two" and forward.selection.focus == 0
}

expect {
	text = "one two"
	double = LineEditingInternal.start_pointer_selection(text, LineEditingInternal.empty_selection, 5, 2, Bool.False)
	extended = LineEditingInternal.continue_drag(text, double, 1)
	triple = LineEditingInternal.start_pointer_selection(text, LineEditingInternal.empty_selection, 5, 3, Bool.False)
	double.anchor == 4 and double.focus == 7 and extended.anchor == 7 and extended.focus == 0 and triple.anchor == 0 and triple.focus == 7
}

expect {
	action = { ..Event.empty_modifiers, meta: Bool.True }
	selection = { anchor: 2, focus: 2, drag: NotDragging }
	select_event = { key: Character("a"), state: KeyDown, modifiers: action }
	copy_event = { key: Character("c"), state: KeyDown, modifiers: action }
	selected = LineEditingInternal.handle_key("hello", selection, select_event)
	copied = LineEditingInternal.handle_key("hello", { anchor: 1, focus: 4, drag: NotDragging }, copy_event)
	select_matches = match selected {
		Updated(update) => update.text == "hello" and update.selection.anchor == 0 and update.selection.focus == 5
		_ => Bool.False
	}
	copy_matches = match copied {
		Copy(text) => text == "ell"
		_ => Bool.False
	}
	select_matches and copy_matches
}
