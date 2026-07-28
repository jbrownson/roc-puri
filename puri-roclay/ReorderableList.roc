## Roclay composition for a transiently reordered vertical list.
##
## The application supplies item rows, handle rendering, and state callbacks.
## This combinator owns placement-driven drag mechanics: exact handle hits,
## row-sized gaps, target midpoints, and the floating top-layer row.
import geometry.Geometry2d
import puri.Drag
import puri.Event
import puri.Frame
import puri.Geometry
import puri.Handler
import puri.Reorder
import Layout
import roclay.Roclay

ReorderableList := [].{

	HandleDescription : {
		active : Bool,
		pointer_position : [Some(Geometry.Point), None],
	}
	Handle(result, state, event) : HandleDescription => Roclay.Layout(Frame(result, state, event))
	Row(item, result, state, event) : item, Reorder.Index, Roclay.Layout(Frame(result, state, event)) => Roclay.Layout(Frame(result, state, event))
	SetDrag(state) : state, Reorder.State => state
	Commit(state) : state, Reorder.Index, Reorder.Index => state

	Description(item, result, state, event) : {
		items : List(item),
		drag : Reorder.State,
		pointer_position : Geometry.Point,
		empty : Roclay.Layout(Frame(result, state, event)),
		list_config : Roclay.BoxConfig,
		target_margin : Geometry.Scalar,
		handle! : Handle(result, state, event),
		row! : Row(item, result, state, event),
		set_drag! : SetDrag(state),
		commit! : Commit(state),
	}

	View(result, state, event) : {
		list : Roclay.Layout(Frame(result, state, event)),
		overlay! : Frame.Widget(result, state, event),
	}

	build! : Description(item, result, state, Drag.Events(events)) => View(result, state, Drag.Events(events))
		where [result.default : result, result.plus : result, result -> result]
	build! = |description| {
		list = build_list!(description)
		overlay! = build_overlay!(description)
		{ list, overlay! }
	}
}

handle_for! : ReorderableList.Description(item, result, state, Drag.Events(events)), Reorder.Index => Roclay.Layout(Frame(result, state, Drag.Events(events)))
	where [result.default : result]
handle_for! = |description, item_index| {
	active = match description.drag {
		Dragging(preview) => preview.source_index == item_index
		Armed(source_index) => source_index == item_index
		Idle => Bool.False
	}
	pointer_position = match description.drag {
		Idle => Some(description.pointer_position)
		Armed(source_index) => if source_index == item_index Some(description.pointer_position) else None
		Dragging(preview) => if preview.source_index == item_index Some(description.pointer_position) else None
	}
	handle = (description.handle!)({ active, pointer_position })
	begin! : Drag.Begin(state)
	begin! = |state, _placement, _pointer| (description.set_drag!)(state, Reorder.arm(item_index))
	source_enabled = match description.drag {
		Idle => Bool.True
		Armed(_) | Dragging(_) => Bool.False
	}
	Layout.after(Drag.source(source_enabled, begin!), handle)
}

row_for! : ReorderableList.Description(item, result, state, Drag.Events(events)), item, Reorder.Index => Roclay.Layout(Frame(result, state, Drag.Events(events)))
	where [result.default : result]
row_for! = |description, item, item_index| {
	handle = handle_for!(description, item_index)
	row = (description.row!)(item, item_index, handle)
	match description.drag {
		Armed(source_index) if source_index == item_index => {
			activate! : Drag.Move(state)
			activate! = |state, placement, pointer| {
				active = Reorder.activate(description.drag, placement.rect, pointer.position)
				Handled((description.set_drag!)(state, active))
			}
			Layout.after(Drag.motion(Bool.True, activate!), row)
		}
		_ => row
	}
}

target! : ReorderableList.Description(item, result, state, Drag.Events(events)), Reorder.Index -> Frame.Widget(result, state, Drag.Events(events))
	where [result.default : result]
target! = |description, row_index| {
	move! : Drag.Move(state)
	move! = |state, placement, pointer| match description.drag {
		Dragging(preview) => {
			floating_center = pointer.position.y - preview.grab_offset.y + preview.size.height / 2
			target_top = placement.rect.y - description.target_margin
			target_bottom = placement.rect.y + placement.rect.height + description.target_margin
			if Geometry2d.contains(placement.clip_rect, pointer.position) and floating_center >= target_top and floating_center <= target_bottom {
				midpoint = placement.rect.y + placement.rect.height / 2
				gap_index = if floating_center < midpoint row_index else row_index + 1
				Handled((description.set_drag!)(state, Reorder.set_gap(description.drag, gap_index)))
			} else {
				Declined
			}
		}
		Idle | Armed(_) => Declined
	}
	Drag.motion(Bool.True, move!)
}

build_list! : ReorderableList.Description(item, result, state, Drag.Events(events)) => Roclay.Layout(Frame(result, state, Drag.Events(events)))
	where [result.default : result]
build_list! = |description| {
	var $rows = []
	if List.is_empty(description.items) {
		$rows = List.append($rows, description.empty)
	} else {
		match description.drag {
			Idle | Armed(_) => {
				var $item_index = 0
				for item in description.items {
					$rows = List.append($rows, row_for!(description, item, $item_index))
					$item_index = $item_index + 1
				}
			}
			Dragging(preview) => {
				placeholder = Roclay.fixed(preview.size, |_placement| Frame.default())
				var $item_index = 0
				var $row_index = 0
				for item in description.items {
					if $item_index != preview.source_index {
						if $row_index == preview.gap_index {
							$rows = List.append($rows, placeholder)
						}
						row = row_for!(description, item, $item_index)
						targeted = Layout.after(target!(description, $row_index), row)
						$rows = List.append($rows, targeted)
						$row_index = $row_index + 1
					}
					$item_index = $item_index + 1
				}
				if $row_index == preview.gap_index {
					$rows = List.append($rows, placeholder)
				}
			}
		}
	}
	config = { ..description.list_config, direction: TopToBottom }
	Roclay.box(config, $rows)
}

build_overlay! : ReorderableList.Description(item, result, state, Drag.Events(events)) => Frame.Widget(result, state, Drag.Events(events))
	where [result.default : result, result.plus : result, result -> result]
build_overlay! = |description| {
	|root_placement| {
		finish! : Drag.Finish(state)
		finish! = |state, _placement, _pointer| match description.drag {
			Idle => state
			Armed(_) => (description.set_drag!)(state, Idle)
			Dragging(preview) => {
				committed = (description.commit!)(state, preview.source_index, preview.gap_index)
				(description.set_drag!)(committed, Idle)
			}
		}
		release_enabled = match description.drag {
			Idle => Bool.False
			Armed(_) | Dragging(_) => Bool.True
		}
		release_frame = (Drag.release(release_enabled, finish!))(root_placement)
		match description.drag {
			Idle | Armed(_) => release_frame
			Dragging(preview) => match List.get(description.items, preview.source_index) {
				Err(_) => release_frame
				Ok(item) => {
					origin = Geometry2d.point(
						description.pointer_position.x - preview.grab_offset.x,
						description.pointer_position.y - preview.grab_offset.y,
					)
					rect = Geometry2d.size_rect_at(origin, preview.size)
					placement = Geometry2d.clip_placement(
						root_placement.clip_rect,
						Geometry2d.root_placement(rect),
					)
					layout = row_for!(description, item, preview.source_index)
					overlay = Roclay.place!(layout, placement)
					visual_only = Frame.from_placement_result(overlay.placement_result)
					visual_only + release_frame
				}
			}
		}
	}
}
