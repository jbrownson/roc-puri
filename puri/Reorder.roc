## Layout-independent transient state for pointer-driven list reordering.
##
## Pointer-down on a handle arms an index. The first pointer movement can then
## activate it with the complete settled row geometry supplied by a layout
## adapter. Moving the gap never changes the underlying list.
import geometry.Geometry2d
import Geometry

Reorder := [].{

	Index : U64
	Preview : {
		source_index : Index,
		gap_index : Index,
		grab_offset : Geometry.Point,
		size : Geometry.Size,
	}
	State := [Idle, Armed(Index), Dragging(Preview)]

	idle : State
	idle = Idle

	arm : Index -> State
	arm = |source_index| Armed(source_index)

	activate : State, Geometry.Rect, Geometry.Point -> State
	activate = |state, rect, pointer| match state {
		Armed(source_index) => Dragging({
			source_index,
			gap_index: source_index,
			grab_offset: Geometry2d.point(pointer.x - rect.x, pointer.y - rect.y),
			size: Geometry2d.size(rect.width, rect.height),
		})
		Idle | Dragging(_) => state
	}

	set_gap : State, Index -> State
	set_gap = |state, gap_index| match state {
		Dragging(preview) => if preview.gap_index == gap_index state else Dragging({ ..preview, gap_index })
		Idle | Armed(_) => state
	}

	move : List(item), Index, Index -> List(item)
	move = |items, source_index, gap_index| {
		if gap_index >= List.len(items) {
			items
		} else {
			match List.get(items, source_index) {
				Err(_) => items
				Ok(source_item) => {
					var $without_source = []
					var $item_index = 0
					for item in items {
						if $item_index != source_index {
							$without_source = List.append($without_source, item)
						}
						$item_index = $item_index + 1
					}

					var $moved = []
					var $gap_cursor = 0
					for item in $without_source {
						if $gap_cursor == gap_index {
							$moved = List.append($moved, source_item)
						}
						$moved = List.append($moved, item)
						$gap_cursor = $gap_cursor + 1
					}
					if $gap_cursor == gap_index {
						$moved = List.append($moved, source_item)
					}
					$moved
				}
			}
		}
	}

	move_index : Index, Index, Index -> Index
	move_index = |item_index, source_index, gap_index| if item_index == source_index {
		gap_index
	} else {
		without_source = if item_index > source_index item_index - 1 else item_index
		if without_source >= gap_index without_source + 1 else without_source
	}
}
