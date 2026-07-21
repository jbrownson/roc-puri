## Pure single-line editing transitions.
##
## A Selection contains only interaction facts. Text is supplied independently
## for each transition, so neither this module nor a Puri widget dictates how
## an application normalizes or stores its model. Offsets are UTF-8 byte
## boundaries and are clamped against the supplied text wherever read.
import PuriHandler

PuriLineEdit := [].{

	LineEditSelection : {
		anchor : U64,
		focus : U64,
		dragging : Bool,
	}

	SelectionBounds : {
		start : U64,
		end : U64,
	}

	Edit : {
		text : Str,
		selection : LineEditSelection,
	}

	EditResult := [Edited(Edit), Ignored]

	empty_selection : LineEditSelection
	empty_selection = { anchor: 0, focus: 0, dragging: Bool.False }

	selection_at_end : Str -> LineEditSelection
	selection_at_end = |text| {
		end = Str.count_utf8_bytes(text)
		{ anchor: end, focus: end, dragging: Bool.False }
	}

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
			selection: { anchor: caret, focus: caret, dragging: Bool.False },
		}
	}

	delete_backward : Str, LineEditSelection -> Edit
	delete_backward = |text, source| {
		selection = PuriLineEdit.clamp_selection(text, source)
		bounds = PuriLineEdit.selection_bounds(text, selection)
		if bounds.start != bounds.end {
			PuriLineEdit.replace_selection(text, "", selection)
		} else if bounds.start == 0 {
			{ text, selection: { ..selection, anchor: 0, focus: 0, dragging: Bool.False } }
		} else {
			bytes = Str.to_utf8(text)
			start = PuriLineEdit.previous_boundary(bytes, bounds.start)
			next_text = PuriLineEdit.replace_range(text, start, bounds.start, "")
			{ text: next_text, selection: { anchor: start, focus: start, dragging: Bool.False } }
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
			{ text: next_text, selection: { anchor: bounds.end, focus: bounds.end, dragging: Bool.False } }
		}
	}

	move_focus : Str, LineEditSelection, [Backward, Forward], Bool -> LineEditSelection
	move_focus = |text, source, direction, extend| {
		selection = PuriLineEdit.clamp_selection(text, source)
		bytes = Str.to_utf8(text)
		moved = match direction {
			Backward => PuriLineEdit.previous_boundary(bytes, selection.focus)
			Forward => PuriLineEdit.next_boundary(bytes, selection.focus)
		}
		{
			..selection,
			anchor: if extend selection.anchor else moved,
			focus: moved,
			dragging: Bool.False,
		}
	}

	move_home : LineEditSelection, Bool -> LineEditSelection
	move_home = |selection, extend| {
		{ ..selection, anchor: if extend selection.anchor else 0, focus: 0, dragging: Bool.False }
	}

	move_end : Str, LineEditSelection, Bool -> LineEditSelection
	move_end = |text, source, extend| {
		selection = PuriLineEdit.clamp_selection(text, source)
		end = Str.count_utf8_bytes(text)
		{ ..selection, anchor: if extend selection.anchor else end, focus: end, dragging: Bool.False }
	}

	start_drag : Str, U64 -> LineEditSelection
	start_drag = |text, requested| {
		index = PuriLineEdit.boundary_at_or_before(Str.to_utf8(text), requested)
		{ anchor: index, focus: index, dragging: Bool.True }
	}

	continue_drag : Str, LineEditSelection, U64 -> LineEditSelection
	continue_drag = |text, source, requested| {
		selection = PuriLineEdit.clamp_selection(text, source)
		index = PuriLineEdit.boundary_at_or_before(Str.to_utf8(text), requested)
		{ ..selection, focus: index }
	}

	end_drag : LineEditSelection -> LineEditSelection
	end_drag = |selection| { ..selection, dragging: Bool.False }

	handle_key : Str, LineEditSelection, PuriHandler.KeyEvent -> EditResult
	handle_key = |text, selection, event| match event.state {
		KeyUp => Ignored
		KeyDown => match event.key {
			Character(string) => if event.modifiers.ctrl or event.modifiers.meta {
				Ignored
			} else {
				Edited(PuriLineEdit.replace_selection(text, string, selection))
			}
			Named(Backspace) => Edited(PuriLineEdit.delete_backward(text, selection))
			Named(Delete) => Edited(PuriLineEdit.delete_forward(text, selection))
			Named(ArrowLeft) => Edited({ text, selection: PuriLineEdit.move_focus(text, selection, Backward, event.modifiers.shift) })
			Named(ArrowRight) => Edited({ text, selection: PuriLineEdit.move_focus(text, selection, Forward, event.modifiers.shift) })
			Named(Home) => Edited({ text, selection: PuriLineEdit.move_home(selection, event.modifiers.shift) })
			Named(End) => Edited({ text, selection: PuriLineEdit.move_end(text, selection, event.modifiers.shift) })
			Named(Space) => Edited(PuriLineEdit.replace_selection(text, " ", selection))
			_ => Ignored
		}
	}
}

expect {
	selection = PuriLineEdit.selection_at_end("hi")
	event = { key: Character("!"), state: KeyDown, modifiers: PuriHandler.empty_modifiers }
	match PuriLineEdit.handle_key("hi", selection, event) {
		Edited(edit) => edit == { text: "hi!", selection: PuriLineEdit.selection_at_end("hi!") }
		Ignored => Bool.False
	}
}

expect {
	first = PuriLineEdit.delete_backward("a🐦b", PuriLineEdit.selection_at_end("a🐦b"))
	second = PuriLineEdit.delete_backward(first.text, first.selection)
	first.text == "a🐦" and first.selection.focus == 5 and second.text == "a" and second.selection.focus == 1
}

expect {
	selection = { anchor: 1, focus: 4, dragging: Bool.False }
	replaced = PuriLineEdit.replace_selection("hello", "i", selection)
	replaced == { text: "hio", selection: { anchor: 2, focus: 2, dragging: Bool.False } }
}
