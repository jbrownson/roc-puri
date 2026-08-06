app [main!] {
	test_host: platform "./platform/main.roc",
	geometry: "https://github.com/jbrownson/roc-puri-geometry/releases/download/0.1.0/8YcrEeY7J3K9khuA2ULAcMZvzAbqPzdT9qKCDX9YvqSP.tar.zst",
	puri: "../main.roc",
}

import geometry.Geometry2d
import puri.Reorder

preview_matches : Reorder.State, U64, U64, Geometry2d.Point(F32), Geometry2d.Size(F32) -> Bool
preview_matches = |state, source_index, gap_index, grab_offset, size| match state {
	Dragging(preview) => preview.source_index == source_index and preview.gap_index == gap_index and preview.grab_offset == grab_offset and preview.size == size
	Idle | Armed(_) => Bool.False
}

is_idle : Reorder.State -> Bool
is_idle = |state| match state {
	Idle => Bool.True
	Armed(_) | Dragging(_) => Bool.False
}

is_armed_at : Reorder.State, U64 -> Bool
is_armed_at = |state, expected| match state {
	Armed(index) => index == expected
	Idle | Dragging(_) => Bool.False
}

arms_then_activates_from_settled_geometry! : () => Bool
arms_then_activates_from_settled_geometry! = || {
	armed = Reorder.arm(2)
	active = Reorder.activate(
		armed,
		Geometry2d.rect(10, 20, 200, 50),
		Geometry2d.point(18, 33),
	)
	preview_matches(active, 2, 2, Geometry2d.point(8, 13), Geometry2d.size(200, 50))
}

gap_updates_only_an_active_drag! : () => Bool
gap_updates_only_an_active_drag! = || {
	active = Reorder.activate(
		Reorder.arm(2),
		Geometry2d.rect(10, 20, 200, 50),
		Geometry2d.point(18, 33),
	)
	moved = Reorder.set_gap(active, 0)
	idle_unchanged = is_idle(Reorder.set_gap(Idle, 3))
	armed_unchanged = is_armed_at(Reorder.set_gap(Armed(2), 3), 2)
	preview_matches(moved, 2, 0, Geometry2d.point(8, 13), Geometry2d.size(200, 50)) and idle_unchanged and armed_unchanged
}

move_reorders_items_and_their_indices! : () => Bool
move_reorders_items_and_their_indices! = || {
	moved_up = Reorder.move(["a", "b", "c"], 2, 0)
	moved_down = Reorder.move(["a", "b", "c"], 0, 2)
	moved_up == ["c", "a", "b"]
		and moved_down == ["b", "c", "a"]
			and Reorder.move_index(2, 2, 0) == 0
				and Reorder.move_index(0, 2, 0) == 1
					and Reorder.move_index(0, 0, 2) == 2
						and Reorder.move_index(2, 0, 2) == 1
}

main! = || if arms_then_activates_from_settled_geometry!() and gap_updates_only_an_active_drag!() and move_reorders_items_and_their_indices!() 0 else 1
