## Pure single-line editing transitions.
##
## A Selection contains only interaction facts. Text is supplied independently
## for each transition, so neither this module nor a Puri widget dictates how
## an application normalizes or stores its model. Offsets are UTF-8 byte
## boundaries and are clamped against the supplied text wherever read.
import PuriHandler

PuriLineEdit := [].{

	SelectionBounds : {
		start : U64,
		end : U64,
	}

	Drag := [CharacterDrag, WordDrag(SelectionBounds), AllDrag, NotDragging]

	LineEditSelection : {
		anchor : U64,
		focus : U64,
		drag : Drag,
	}

	Edit : {
		text : Str,
		selection : LineEditSelection,
	}

	EditResult := [Edited(Edit), Copy(Str), Cut({ copied : Str, edit : Edit }), Paste, Ignored]

	empty_selection : LineEditSelection
	empty_selection = { anchor: 0, focus: 0, drag: NotDragging }

	selection_at_end : Str -> LineEditSelection
	selection_at_end = |text| {
		end = Str.count_utf8_bytes(text)
		{ anchor: end, focus: end, drag: NotDragging }
	}

	is_dragging : LineEditSelection -> Bool
	is_dragging = |selection| match selection.drag {
		NotDragging => Bool.False
		_ => Bool.True
	}

	# UTF-8 boundaries and basic editing.

	is_continuation_byte : U8 -> Bool
	is_continuation_byte = |byte| byte >= 128 and byte < 192

	boundary_at_or_before : List(U8), U64 -> U64
	boundary_at_or_before = |bytes, requested| {
		length = List.len(bytes)
		index = U64.min(requested, length)
		if index == 0 or index == length {
			index
		} else match List.get(bytes, index) {
			Ok(byte) => if PuriLineEdit.is_continuation_byte(byte) {
				PuriLineEdit.boundary_at_or_before(bytes, index - 1)
			} else {
				index
			}
			Err(_) => length
		}
	}

	next_boundary_from : List(U8), U64 -> U64
	next_boundary_from = |bytes, index| if index >= List.len(bytes) {
		List.len(bytes)
	} else match List.get(bytes, index) {
		Ok(byte) => if PuriLineEdit.is_continuation_byte(byte) {
			PuriLineEdit.next_boundary_from(bytes, index + 1)
		} else {
			index
		}
		Err(_) => List.len(bytes)
	}

	previous_boundary : List(U8), U64 -> U64
	previous_boundary = |bytes, requested| {
		current = PuriLineEdit.boundary_at_or_before(bytes, requested)
		if current == 0 0 else PuriLineEdit.boundary_at_or_before(bytes, current - 1)
	}

	next_boundary : List(U8), U64 -> U64
	next_boundary = |bytes, requested| {
		current = PuriLineEdit.boundary_at_or_before(bytes, requested)
		if current >= List.len(bytes) List.len(bytes) else PuriLineEdit.next_boundary_from(bytes, current + 1)
	}

	clamp_selection : Str, LineEditSelection -> LineEditSelection
	clamp_selection = |text, selection| {
		bytes = Str.to_utf8(text)
		{
			..selection,
			anchor: PuriLineEdit.boundary_at_or_before(bytes, selection.anchor),
			focus: PuriLineEdit.boundary_at_or_before(bytes, selection.focus),
		}
	}

	selection_bounds : Str, LineEditSelection -> SelectionBounds
	selection_bounds = |text, source| {
		selection = PuriLineEdit.clamp_selection(text, source)
		{
			start: U64.min(selection.anchor, selection.focus),
			end: U64.max(selection.anchor, selection.focus),
		}
	}

	append_bytes : List(U8), List(U8) -> List(U8)
	append_bytes = |left, right| {
		var $combined = left
		for byte in right {
			$combined = List.append($combined, byte)
		}
		$combined
	}

	prefix : Str, U64 -> Str
	prefix = |source, requested| {
		bytes = Str.to_utf8(source)
		end = PuriLineEdit.boundary_at_or_before(bytes, requested)
		match Str.from_utf8(List.take_first(bytes, end)) {
			Ok(string) => string
			Err(_) => ""
		}
	}

	slice : Str, U64, U64 -> Str
	slice = |source, requested_start, requested_end| {
		bytes = Str.to_utf8(source)
		first = PuriLineEdit.boundary_at_or_before(bytes, requested_start)
		second = PuriLineEdit.boundary_at_or_before(bytes, requested_end)
		start = U64.min(first, second)
		end = U64.max(first, second)
		match Str.from_utf8(List.take_first(List.drop_first(bytes, start), end - start)) {
			Ok(string) => string
			Err(_) => ""
		}
	}

	replace_range : Str, U64, U64, Str -> Str
	replace_range = |source, start, end, inserted| {
		bytes = Str.to_utf8(source)
		lo = PuriLineEdit.boundary_at_or_before(bytes, start)
		hi = PuriLineEdit.boundary_at_or_before(bytes, end)
		prefix_bytes = List.take_first(bytes, lo)
		suffix = List.drop_first(bytes, hi)
		with_insert = PuriLineEdit.append_bytes(prefix_bytes, Str.to_utf8(inserted))
		match Str.from_utf8(PuriLineEdit.append_bytes(with_insert, suffix)) {
			Ok(string) => string
			Err(_) => source
		}
	}

	replace_selection : Str, Str, LineEditSelection -> Edit
	replace_selection = |text, inserted, source| {
		selection = PuriLineEdit.clamp_selection(text, source)
		bounds = PuriLineEdit.selection_bounds(text, selection)
		next_text = PuriLineEdit.replace_range(text, bounds.start, bounds.end, inserted)
		caret = bounds.start + Str.count_utf8_bytes(inserted)
		{
			text: next_text,
			selection: { anchor: caret, focus: caret, drag: NotDragging },
		}
	}

	selected_text : Str, LineEditSelection -> [Some(Str), None]
	selected_text = |text, selection| {
		bounds = PuriLineEdit.selection_bounds(text, selection)
		if bounds.start == bounds.end None else Some(PuriLineEdit.slice(text, bounds.start, bounds.end))
	}

	delete_backward : Str, LineEditSelection -> Edit
	delete_backward = |text, source| {
		selection = PuriLineEdit.clamp_selection(text, source)
		bounds = PuriLineEdit.selection_bounds(text, selection)
		if bounds.start != bounds.end {
			PuriLineEdit.replace_selection(text, "", selection)
		} else if bounds.start == 0 {
			{ text, selection: { ..selection, anchor: 0, focus: 0, drag: NotDragging } }
		} else {
			bytes = Str.to_utf8(text)
			start = PuriLineEdit.previous_boundary(bytes, bounds.start)
			next_text = PuriLineEdit.replace_range(text, start, bounds.start, "")
			{ text: next_text, selection: { anchor: start, focus: start, drag: NotDragging } }
		}
	}

	delete_forward : Str, LineEditSelection -> Edit
	delete_forward = |text, source| {
		selection = PuriLineEdit.clamp_selection(text, source)
		bounds = PuriLineEdit.selection_bounds(text, selection)
		if bounds.start != bounds.end {
			PuriLineEdit.replace_selection(text, "", selection)
		} else {
			bytes = Str.to_utf8(text)
			end = PuriLineEdit.next_boundary(bytes, bounds.end)
			next_text = PuriLineEdit.replace_range(text, bounds.end, end, "")
			{ text: next_text, selection: { anchor: bounds.end, focus: bounds.end, drag: NotDragging } }
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
		Ok(byte) => PuriLineEdit.byte_class(byte)
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
		previous = PuriLineEdit.previous_boundary(bytes, index)
		if PuriLineEdit.same_class(PuriLineEdit.class_at(bytes, previous), class) {
			PuriLineEdit.scan_class_backward(bytes, previous, class)
		} else {
			index
		}
	}

	scan_class_forward : List(U8), U64, ByteClass -> U64
	scan_class_forward = |bytes, index, class| if index >= List.len(bytes) {
		List.len(bytes)
	} else if PuriLineEdit.same_class(PuriLineEdit.class_at(bytes, index), class) {
		PuriLineEdit.scan_class_forward(bytes, PuriLineEdit.next_boundary(bytes, index), class)
	} else {
		index
	}

	word_bounds : Str, U64 -> SelectionBounds
	word_bounds = |text, requested| {
		bytes = Str.to_utf8(text)
		length = List.len(bytes)
		index = if requested >= length and length > 0 {
			PuriLineEdit.previous_boundary(bytes, length)
		} else {
			PuriLineEdit.boundary_at_or_before(bytes, requested)
		}
		class = PuriLineEdit.class_at(bytes, index)
		{
			start: PuriLineEdit.scan_class_backward(bytes, index, class),
			end: PuriLineEdit.scan_class_forward(bytes, index, class),
		}
	}

	previous_word_boundary_from : List(U8), U64 -> U64
	previous_word_boundary_from = |bytes, index| if index == 0 {
		0
	} else {
		previous = PuriLineEdit.previous_boundary(bytes, index)
		if PuriLineEdit.same_class(PuriLineEdit.class_at(bytes, previous), WordByte) {
			PuriLineEdit.scan_class_backward(bytes, index, WordByte)
		} else {
			PuriLineEdit.previous_word_boundary_from(bytes, previous)
		}
	}

	previous_word_boundary : Str, U64 -> U64
	previous_word_boundary = |text, requested| {
		bytes = Str.to_utf8(text)
		PuriLineEdit.previous_word_boundary_from(bytes, PuriLineEdit.boundary_at_or_before(bytes, requested))
	}

	next_word_boundary_from : List(U8), U64 -> U64
	next_word_boundary_from = |bytes, index| if index >= List.len(bytes) {
		List.len(bytes)
	} else if PuriLineEdit.same_class(PuriLineEdit.class_at(bytes, index), WordByte) {
		PuriLineEdit.scan_class_forward(bytes, index, WordByte)
	} else {
		PuriLineEdit.next_word_boundary_from(bytes, PuriLineEdit.next_boundary(bytes, index))
	}

	next_word_boundary : Str, U64 -> U64
	next_word_boundary = |text, requested| {
		bytes = Str.to_utf8(text)
		PuriLineEdit.next_word_boundary_from(bytes, PuriLineEdit.boundary_at_or_before(bytes, requested))
	}

	move_focus : Str, LineEditSelection, [Backward, Forward], Bool -> LineEditSelection
	move_focus = |text, source, direction, extend| {
		selection = PuriLineEdit.clamp_selection(text, source)
		bytes = Str.to_utf8(text)
		bounds = PuriLineEdit.selection_bounds(text, selection)
		moved = if !extend and bounds.start != bounds.end {
			match direction {
				Backward => bounds.start
				Forward => bounds.end
			}
		} else match direction {
			Backward => PuriLineEdit.previous_boundary(bytes, selection.focus)
			Forward => PuriLineEdit.next_boundary(bytes, selection.focus)
		}
		{
			..selection,
			anchor: if extend selection.anchor else moved,
			focus: moved,
			drag: NotDragging,
		}
	}

	move_word : Str, LineEditSelection, [Backward, Forward], Bool -> LineEditSelection
	move_word = |text, source, direction, extend| {
		selection = PuriLineEdit.clamp_selection(text, source)
		bounds = PuriLineEdit.selection_bounds(text, selection)
		moved = if !extend and bounds.start != bounds.end {
			match direction {
				Backward => bounds.start
				Forward => bounds.end
			}
		} else match direction {
			Backward => PuriLineEdit.previous_word_boundary(text, selection.focus)
			Forward => PuriLineEdit.next_word_boundary(text, selection.focus)
		}
		{
			..selection,
			anchor: if extend selection.anchor else moved,
			focus: moved,
			drag: NotDragging,
		}
	}

	move_home : LineEditSelection, Bool -> LineEditSelection
	move_home = |selection, extend| {
		{ ..selection, anchor: if extend selection.anchor else 0, focus: 0, drag: NotDragging }
	}

	move_end : Str, LineEditSelection, Bool -> LineEditSelection
	move_end = |text, source, extend| {
		selection = PuriLineEdit.clamp_selection(text, source)
		end = Str.count_utf8_bytes(text)
		{ ..selection, anchor: if extend selection.anchor else end, focus: end, drag: NotDragging }
	}

	select_all : Str -> LineEditSelection
	select_all = |text| { anchor: 0, focus: Str.count_utf8_bytes(text), drag: NotDragging }

	delete_word_backward : Str, LineEditSelection -> Edit
	delete_word_backward = |text, source| {
		selection = PuriLineEdit.clamp_selection(text, source)
		bounds = PuriLineEdit.selection_bounds(text, selection)
		if bounds.start != bounds.end {
			PuriLineEdit.replace_selection(text, "", selection)
		} else {
			start = PuriLineEdit.previous_word_boundary(text, bounds.start)
			next_text = PuriLineEdit.replace_range(text, start, bounds.start, "")
			{ text: next_text, selection: { anchor: start, focus: start, drag: NotDragging } }
		}
	}

	delete_word_forward : Str, LineEditSelection -> Edit
	delete_word_forward = |text, source| {
		selection = PuriLineEdit.clamp_selection(text, source)
		bounds = PuriLineEdit.selection_bounds(text, selection)
		if bounds.start != bounds.end {
			PuriLineEdit.replace_selection(text, "", selection)
		} else {
			end = PuriLineEdit.next_word_boundary(text, bounds.end)
			next_text = PuriLineEdit.replace_range(text, bounds.end, end, "")
			{ text: next_text, selection: { anchor: bounds.end, focus: bounds.end, drag: NotDragging } }
		}
	}

	delete_to_start : Str, LineEditSelection -> Edit
	delete_to_start = |text, source| {
		selection = PuriLineEdit.clamp_selection(text, source)
		bounds = PuriLineEdit.selection_bounds(text, selection)
		if bounds.start != bounds.end {
			PuriLineEdit.replace_selection(text, "", selection)
		} else {
			next_text = PuriLineEdit.replace_range(text, 0, bounds.start, "")
			{ text: next_text, selection: PuriLineEdit.empty_selection }
		}
	}

	delete_to_end : Str, LineEditSelection -> Edit
	delete_to_end = |text, source| {
		selection = PuriLineEdit.clamp_selection(text, source)
		bounds = PuriLineEdit.selection_bounds(text, selection)
		if bounds.start != bounds.end {
			PuriLineEdit.replace_selection(text, "", selection)
		} else {
			next_text = PuriLineEdit.replace_range(text, bounds.end, Str.count_utf8_bytes(text), "")
			{ text: next_text, selection: { anchor: bounds.end, focus: bounds.end, drag: NotDragging } }
		}
	}

	# Pointer-driven selection.

	start_pointer_selection : Str, LineEditSelection, U64, U8, Bool -> LineEditSelection
	start_pointer_selection = |text, source, requested, clicks, extend| if clicks >= 3 {
		{ anchor: 0, focus: Str.count_utf8_bytes(text), drag: AllDrag }
	} else if clicks == 2 {
		bounds = PuriLineEdit.word_bounds(text, requested)
		{ anchor: bounds.start, focus: bounds.end, drag: WordDrag(bounds) }
	} else {
		index = PuriLineEdit.boundary_at_or_before(Str.to_utf8(text), requested)
		selection = PuriLineEdit.clamp_selection(text, source)
		{ anchor: if extend selection.anchor else index, focus: index, drag: CharacterDrag }
	}

	continue_drag : Str, LineEditSelection, U64 -> LineEditSelection
	continue_drag = |text, source, requested| {
		selection = PuriLineEdit.clamp_selection(text, source)
		index = PuriLineEdit.boundary_at_or_before(Str.to_utf8(text), requested)
		match selection.drag {
			CharacterDrag => { ..selection, focus: index }
			WordDrag(origin) => {
				target = PuriLineEdit.word_bounds(text, index)
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

	end_drag : LineEditSelection -> LineEditSelection
	end_drag = |selection| { ..selection, drag: NotDragging }

	# Desktop single-line key bindings.

	handle_key : Str, LineEditSelection, PuriHandler.KeyEvent -> EditResult
	handle_key = |text, selection, event| match event.state {
		KeyUp => Ignored
		KeyDown => match event.key {
			Character(string) if (event.modifiers.meta or event.modifiers.ctrl) and Str.caseless_ascii_equals(string, "a") => Edited({ text, selection: PuriLineEdit.select_all(text) })
			Character(string) if (event.modifiers.meta or event.modifiers.ctrl) and Str.caseless_ascii_equals(string, "c") => match PuriLineEdit.selected_text(text, selection) {
				Some(selected) => Copy(selected)
				None => Ignored
			}
			Character(string) if (event.modifiers.meta or event.modifiers.ctrl) and Str.caseless_ascii_equals(string, "x") => match PuriLineEdit.selected_text(text, selection) {
				Some(selected) => Cut({ copied: selected, edit: PuriLineEdit.replace_selection(text, "", selection) })
				None => Ignored
			}
			Character(string) if (event.modifiers.meta or event.modifiers.ctrl) and Str.caseless_ascii_equals(string, "v") => Paste
			Character(string) => if event.modifiers.ctrl or event.modifiers.meta {
				Ignored
			} else {
				Edited(PuriLineEdit.replace_selection(text, string, selection))
			}
			Named(Backspace) => if event.modifiers.meta {
				Edited(PuriLineEdit.delete_to_start(text, selection))
			} else if event.modifiers.alt or event.modifiers.ctrl {
				Edited(PuriLineEdit.delete_word_backward(text, selection))
			} else {
				Edited(PuriLineEdit.delete_backward(text, selection))
			}
			Named(Delete) => if event.modifiers.meta {
				Edited(PuriLineEdit.delete_to_end(text, selection))
			} else if event.modifiers.alt or event.modifiers.ctrl {
				Edited(PuriLineEdit.delete_word_forward(text, selection))
			} else {
				Edited(PuriLineEdit.delete_forward(text, selection))
			}
			Named(ArrowLeft) => if event.modifiers.meta {
				Edited({ text, selection: PuriLineEdit.move_home(selection, event.modifiers.shift) })
			} else if event.modifiers.alt or event.modifiers.ctrl {
				Edited({ text, selection: PuriLineEdit.move_word(text, selection, Backward, event.modifiers.shift) })
			} else {
				Edited({ text, selection: PuriLineEdit.move_focus(text, selection, Backward, event.modifiers.shift) })
			}
			Named(ArrowRight) => if event.modifiers.meta {
				Edited({ text, selection: PuriLineEdit.move_end(text, selection, event.modifiers.shift) })
			} else if event.modifiers.alt or event.modifiers.ctrl {
				Edited({ text, selection: PuriLineEdit.move_word(text, selection, Forward, event.modifiers.shift) })
			} else {
				Edited({ text, selection: PuriLineEdit.move_focus(text, selection, Forward, event.modifiers.shift) })
			}
			Named(Home) => Edited({ text, selection: PuriLineEdit.move_home(selection, event.modifiers.shift) })
			Named(End) => Edited({ text, selection: PuriLineEdit.move_end(text, selection, event.modifiers.shift) })
			Named(Space) => if event.modifiers.ctrl or event.modifiers.meta Ignored else Edited(PuriLineEdit.replace_selection(text, " ", selection))
			_ => Ignored
		}
	}
}

expect {
	selection = PuriLineEdit.selection_at_end("hi")
	event = { key: Character("!"), state: KeyDown, modifiers: PuriHandler.empty_modifiers }
	match PuriLineEdit.handle_key("hi", selection, event) {
		Edited(edit) => edit.text == "hi!" and edit.selection.anchor == 3 and edit.selection.focus == 3
		_ => Bool.False
	}
}

expect {
	first = PuriLineEdit.delete_backward("a🐦b", PuriLineEdit.selection_at_end("a🐦b"))
	second = PuriLineEdit.delete_backward(first.text, first.selection)
	first.text == "a🐦" and first.selection.focus == 5 and second.text == "a" and second.selection.focus == 1
}

expect {
	selection = { anchor: 1, focus: 4, drag: NotDragging }
	replaced = PuriLineEdit.replace_selection("hello", "i", selection)
	replaced.text == "hio" and replaced.selection.anchor == 2 and replaced.selection.focus == 2 and !(PuriLineEdit.is_dragging(replaced.selection))
}

expect {
	selection = { anchor: 1, focus: 4, drag: NotDragging }
	left = PuriLineEdit.move_focus("hello", selection, Backward, Bool.False)
	right = PuriLineEdit.move_focus("hello", selection, Forward, Bool.False)
	left.anchor == 1 and left.focus == 1 and right.anchor == 4 and right.focus == 4
}

expect {
	text = "one, two  three"
	bounds = PuriLineEdit.word_bounds(text, 6)
	backward = PuriLineEdit.move_word(text, { anchor: 15, focus: 15, drag: NotDragging }, Backward, Bool.False)
	forward = PuriLineEdit.move_word(text, PuriLineEdit.empty_selection, Forward, Bool.False)
	bounds.start == 5 and bounds.end == 8 and backward.focus == 10 and forward.focus == 3
}

expect {
	text = "one, two"
	backward = PuriLineEdit.delete_word_backward(text, PuriLineEdit.selection_at_end(text))
	forward = PuriLineEdit.delete_word_forward(text, PuriLineEdit.empty_selection)
	backward.text == "one, " and backward.selection.focus == 5 and forward.text == ", two" and forward.selection.focus == 0
}

expect {
	text = "one two"
	double = PuriLineEdit.start_pointer_selection(text, PuriLineEdit.empty_selection, 5, 2, Bool.False)
	extended = PuriLineEdit.continue_drag(text, double, 1)
	triple = PuriLineEdit.start_pointer_selection(text, PuriLineEdit.empty_selection, 5, 3, Bool.False)
	double.anchor == 4 and double.focus == 7 and extended.anchor == 7 and extended.focus == 0 and triple.anchor == 0 and triple.focus == 7
}

expect {
	action = { ..PuriHandler.empty_modifiers, meta: Bool.True }
	selection = { anchor: 2, focus: 2, drag: NotDragging }
	select_event = { key: Character("a"), state: KeyDown, modifiers: action }
	copy_event = { key: Character("c"), state: KeyDown, modifiers: action }
	selected = PuriLineEdit.handle_key("hello", selection, select_event)
	copied = PuriLineEdit.handle_key("hello", { anchor: 1, focus: 4, drag: NotDragging }, copy_event)
	select_matches = match selected {
		Edited(edit) => edit.text == "hello" and edit.selection.anchor == 0 and edit.selection.focus == 5
		_ => Bool.False
	}
	copy_matches = match copied {
		Copy(text) => text == "ell"
		_ => Bool.False
	}
	select_matches and copy_matches
}
