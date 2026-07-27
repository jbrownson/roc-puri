## Package-private helpers for treating Roc strings as UTF-8 byte sequences
## while keeping every externally visible offset on a code-point boundary.

Utf8 := [].{

	is_continuation_byte : U8 -> Bool
	is_continuation_byte = |byte| byte >= 128 and byte < 192

	boundary_at_or_before : List(U8), U64 -> U64
	boundary_at_or_before = |bytes, requested| {
		length = List.len(bytes)
		index = U64.min(requested, length)
		if index == 0 or index == length {
			index
		} else match List.get(bytes, index) {
			Ok(byte) => if Utf8.is_continuation_byte(byte) {
				Utf8.boundary_at_or_before(bytes, index - 1)
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
		Ok(byte) => if Utf8.is_continuation_byte(byte) {
			Utf8.next_boundary_from(bytes, index + 1)
		} else {
			index
		}
		Err(_) => List.len(bytes)
	}

	previous_boundary : List(U8), U64 -> U64
	previous_boundary = |bytes, requested| {
		current = Utf8.boundary_at_or_before(bytes, requested)
		if current == 0 0 else Utf8.boundary_at_or_before(bytes, current - 1)
	}

	next_boundary : List(U8), U64 -> U64
	next_boundary = |bytes, requested| {
		current = Utf8.boundary_at_or_before(bytes, requested)
		if current >= List.len(bytes) List.len(bytes) else Utf8.next_boundary_from(bytes, current + 1)
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
		end = Utf8.boundary_at_or_before(bytes, requested)
		match Str.from_utf8(List.take_first(bytes, end)) {
			Ok(string) => string
			Err(_) => ""
		}
	}

	slice : Str, U64, U64 -> Str
	slice = |source, requested_start, requested_end| {
		bytes = Str.to_utf8(source)
		first = Utf8.boundary_at_or_before(bytes, requested_start)
		second = Utf8.boundary_at_or_before(bytes, requested_end)
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
		lo = Utf8.boundary_at_or_before(bytes, start)
		hi = Utf8.boundary_at_or_before(bytes, end)
		prefix_bytes = List.take_first(bytes, lo)
		suffix = List.drop_first(bytes, hi)
		with_insert = Utf8.append_bytes(prefix_bytes, Str.to_utf8(inserted))
		match Str.from_utf8(Utf8.append_bytes(with_insert, suffix)) {
			Ok(string) => string
			Err(_) => source
		}
	}
}

expect {
	bytes = Str.to_utf8("a🐦b")
	Utf8.boundary_at_or_before(bytes, 3) == 1 and Utf8.next_boundary(bytes, 1) == 5 and Utf8.previous_boundary(bytes, 5) == 1
}

expect Utf8.prefix("a🐦b", 3) == "a"

expect Utf8.slice("a🐦b", 1, 5) == "🐦"

expect Utf8.replace_range("a🐦b", 1, 5, "x") == "axb"
