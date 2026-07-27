## A composable placement recording used by Roclay's conformance tests.
RoclayRecording := [].{

	Recording(item) := {
		items : List(item),
	}.{
		default : () -> Recording(item)
		default = || { items: [] }

		plus : Recording(item), Recording(item) -> Recording(item)
		plus = |earlier, later| { items: List.concat(earlier.items, later.items) }
	}

	one : item -> Recording(item)
	one = |item| { items: [item] }
}
