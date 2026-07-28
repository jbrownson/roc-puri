app [main!] {
	test_host: platform "./platform/main.roc",
	geometry: "../../geometry/main.roc",
	puri: "../../puri/main.roc",
	puri_roclay: "../main.roc",
	roclay: "../../roclay/main.roc",
}

import geometry.Geometry2d
import puri.Drag
import puri.Event
import puri.Frame
import puri.Handler
import puri.Reorder
import puri_roclay.ReorderableList
import roclay.Roclay

TestResult := {}.{
	default : () -> TestResult
	default = || {}

	plus : TestResult, TestResult -> TestResult
	plus = |_earlier, _later| {}
}

State : {
	drag : Reorder.State,
	committed_source : U64,
	committed_gap : U64,
}

initial : State
initial = {
	drag: Reorder.idle,
	committed_source: 99,
	committed_gap: 99,
}

set_drag! : State, Reorder.State => State
set_drag! = |state, drag| { ..state, drag }

commit! : State, U64, U64 => State
commit! = |state, committed_source, committed_gap| { ..state, committed_source, committed_gap }

handle! : ReorderableList.Handle(TestResult, State, event)
handle! = |_description| Roclay.fixed(Geometry2d.size(10, 10), |_placement| Frame.default())

row! : ReorderableList.Row(Str, TestResult, State, event)
row! = |_item, _index, handle| {
	Roclay.box(
		{
			..Roclay.default_box,
			sizing: { width: Fill(Roclay.unbounded), height: Fixed(20) },
		},
		[handle],
	)
}

build! : State, Geometry2d.Point(F32) => ReorderableList.View(TestResult, State, Drag.Events(events))
build! = |state, pointer_position| {
	ReorderableList.build!({
		items: ["one", "two"],
		drag: state.drag,
		pointer_position,
		empty: Roclay.spacer(Roclay.zero_size),
		list_config: { ..Roclay.default_box, direction: TopToBottom, gap: 12, sizing: { width: Fill(Roclay.unbounded), height: Fit(Roclay.unbounded) } },
		target_margin: 6,
		handle!,
		row!,
		set_drag!,
		commit!,
	})
}

place_list! : ReorderableList.View(TestResult, State, Drag.Events(events)) => Frame(TestResult, State, Drag.Events(events))
place_list! = |view| Roclay.place!(view.list, Geometry2d.root_placement(Geometry2d.rect(0, 0, 100, 52)))

button : Geometry2d.Point(F32) -> Event.PointerButtonEvent
button = |position| {
	timestamp_nanos: 0,
	position,
	button: Some(Primary),
	clicks: 1,
	modifiers: Event.empty_modifiers,
}

is_armed_at : Reorder.State, U64 -> Bool
is_armed_at = |drag, expected| match drag {
	Armed(index) => index == expected
	Idle | Dragging(_) => Bool.False
}

preview_matches : Reorder.State, U64, U64, Geometry2d.Point(F32), Geometry2d.Size(F32) -> Bool
preview_matches = |drag, source_index, gap_index, grab_offset, size| match drag {
	Dragging(preview) => preview.source_index == source_index and preview.gap_index == gap_index and preview.grab_offset == grab_offset and preview.size == size
	Idle | Armed(_) => Bool.False
}

is_idle : Reorder.State -> Bool
is_idle = |drag| match drag {
	Idle => Bool.True
	Armed(_) | Dragging(_) => Bool.False
}

handle_arms_then_row_geometry_activates! : () => Bool
handle_arms_then_row_geometry_activates! = || {
	idle_view = build!(initial, Geometry2d.point(5, 5))
	idle_frame = place_list!(idle_view)
	outside = Handler.dispatch!(idle_frame.handler, initial, PointerDown(button(Geometry2d.point(50, 5))))
	armed = match Handler.dispatch!(idle_frame.handler, initial, PointerDown(button(Geometry2d.point(5, 5)))) {
		Handled(state) => state
		Declined => initial
	}

	armed_view = build!(armed, Geometry2d.point(5, 6))
	active = match Handler.dispatch!(
		(place_list!(armed_view)).handler,
		armed,
		PointerMove({ timestamp_nanos: 0, position: Geometry2d.point(5, 6), modifiers: Event.empty_modifiers }),
	) {
		Handled(state) => state
		Declined => armed
	}

	outside == Declined
		and is_armed_at(armed.drag, 0)
			and preview_matches(active.drag, 0, 0, Geometry2d.point(5, 6), Geometry2d.size(100, 20))
}

movement_changes_only_the_gap_and_release_commits! : () => Bool
movement_changes_only_the_gap_and_release_commits! = || {
	active = {
		..initial,
		drag: Reorder.activate(
			Reorder.arm(0),
			Geometry2d.rect(0, 0, 100, 20),
			Geometry2d.point(5, 6),
		),
	}
	moved_view = build!(active, Geometry2d.point(5, 45))
	moved = match Handler.dispatch!(
		(place_list!(moved_view)).handler,
		active,
		PointerMove({ timestamp_nanos: 0, position: Geometry2d.point(5, 45), modifiers: Event.empty_modifiers }),
	) {
		Handled(state) => state
		Declined => active
	}

	release_view = build!(moved, Geometry2d.point(5, 45))
	root = Geometry2d.root_placement(Geometry2d.rect(0, 0, 100, 52))
	released = match Handler.dispatch!(
		((release_view.overlay!)(root)).handler,
		moved,
		PointerUp(button(Geometry2d.point(5, 45))),
	) {
		Handled(state) => state
		Declined => moved
	}

	preview_matches(moved.drag, 0, 1, Geometry2d.point(5, 6), Geometry2d.size(100, 20))
		and released.committed_source == 0
			and released.committed_gap == 1
				and is_idle(released.drag)
}

main! = || if handle_arms_then_row_geometry_activates!() and movement_changes_only_the_gap_and_release_commits!() 0 else 1
