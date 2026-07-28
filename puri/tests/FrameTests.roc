app [main!] {
	test_host: platform "./platform/main.roc",
	geometry: "../../geometry/main.roc",
	puri: "../main.roc",
	recording: "./support/main.roc",
}

import geometry.Geometry2d
import puri.Frame
import puri.Canvas
import puri.Event
import recording.CanvasRecording
import puri.Handler
import puri.Interact

down_at : F32, F32 -> Event.PointerButtonEvent
down_at = |x, y| {
	timestamp_nanos: 0,
	position: Geometry2d.point(x, y),
	button: Some(Primary),
	clicks: 1,
	modifiers: Event.empty_modifiers,
}

double_down_at : F32, F32 -> Event.PointerButtonEvent
double_down_at = |x, y| { ..down_at(x, y), clicks: 2 }

frame_plus_composes_result_and_handler! : () => Bool
frame_plus_composes_result_and_handler! = || {
	canvas : Canvas.Operations(CanvasRecording.Recording(Str), Str)
	canvas = CanvasRecording.canvas
	outer = Handler.from_function(|value, _event| Handled(value + 1))
	child = Handler.from_function(|value, _event| Handled(value + 10))
	empty_frame : Frame(CanvasRecording.Recording(Str), U64, [PointerDown(Event.PointerButtonEvent)])
	empty_frame = Frame.default()
	outer_frame = Frame.register(outer, empty_frame)
	child_frame = Frame.register(child, Frame.from_placement_result((canvas.fill_rect!)(Geometry2d.rect(0, 0, 5, 5), "child")))
	frame = List.sum([outer_frame, child_frame])
	result = Handler.dispatch!(frame.handler, 0, PointerDown(down_at(1, 1)))
	List.len(frame.placement_result.commands) == 1 and result == Handled(10)
}

clickable_uses_settled_rect! : () => Bool
clickable_uses_settled_rect! = || {
	placement = Geometry2d.root_placement(Geometry2d.rect(10, 10, 20, 10))
	clickable : Frame.Widget(CanvasRecording.Recording(Str), U64, Interact.Events(events))
	clickable = Interact.clickable(|value| value + 1)
	frame = clickable(placement)
	outside = Handler.dispatch!(frame.handler, 0, PointerDown(down_at(9, 15)))
	inside = Handler.dispatch!(frame.handler, 0, PointerDown(down_at(12, 15)))
	outside == Declined and inside == Handled(1)
}

double_click_overrides_single_click_on_second_press! : () => Bool
double_click_overrides_single_click_on_second_press! = || {
	placement = Geometry2d.root_placement(Geometry2d.rect(10, 10, 20, 10))
	clickable : Frame.Widget(CanvasRecording.Recording(Str), U64, Interact.Events(events))
	clickable = Interact.clickable(|value| value + 1)
	double_clickable : Frame.Widget(CanvasRecording.Recording(Str), U64, Interact.Events(events))
	double_clickable = Interact.double_clickable(|value| value + 10)
	frame = clickable(placement) + double_clickable(placement)
	single = Handler.dispatch!(frame.handler, 0, PointerDown(down_at(12, 15)))
	double = Handler.dispatch!(frame.handler, 0, PointerDown(double_down_at(12, 15)))
	single == Handled(1) and double == Handled(10)
}

pointer_action_receives_timestamp! : () => Bool
pointer_action_receives_timestamp! = || {
	placement = Geometry2d.root_placement(Geometry2d.rect(10, 10, 20, 10))
	action! : Interact.PointerAction(U64)
	action! = |_state, pointer| pointer.timestamp_nanos
	widget! : Frame.Widget(CanvasRecording.Recording(Str), U64, Interact.Events(events))
	widget! = Interact.on_primary_pointer_down(|_pointer| Bool.True, action!)
	event = { ..down_at(12, 15), timestamp_nanos: 42 }
	Handler.dispatch!((widget!(placement)).handler, 0, PointerDown(event)) == Handled(42)
}

placed_pointer_filter_can_subdivide_a_widget! : () => Bool
placed_pointer_filter_can_subdivide_a_widget! = || {
	placement = Geometry2d.root_placement(Geometry2d.rect(10, 10, 20, 10))
	widget! : Frame.Widget(CanvasRecording.Recording(Str), U64, Interact.Events(events))
	widget! = Interact.on_primary_pointer_down_where(
		|placed, pointer| pointer.position.x >= placed.rect.x + 10,
		|state, _placed, _pointer| state + 1,
	)
	frame = widget!(placement)
	left = Handler.dispatch!(frame.handler, 0, PointerDown(down_at(15, 15)))
	right = Handler.dispatch!(frame.handler, 0, PointerDown(down_at(20, 15)))
	left == Declined and right == Handled(1)
}

click_run_adjustment_translates_until_a_new_run! : () => Bool
click_run_adjustment_translates_until_a_new_run! = || {
	canvas : Canvas.Operations(CanvasRecording.Recording(Str), Str)
	canvas = CanvasRecording.canvas
	placement = Geometry2d.root_placement(Geometry2d.rect(10, 10, 20, 10))
	handler = Handler.from_function(
		|state, event| match event {
			PointerDown(pointer) => Handled(state + pointer.clicks)
			_ => Declined
		},
	)
	child_frame : Frame(CanvasRecording.Recording(Str), U8, Interact.Events(events))
	child_frame = Frame.register(handler, Frame.from_placement_result((canvas.fill_rect!)(placement.rect, "child")))
	adjustment : Interact.ClickRunAdjustment(U8)
	adjustment = { subtract: 1, reset!: |state| state + 10 }
	frame = Interact.adjust_click_run(Some(adjustment), placement, child_frame)
	third = Handler.dispatch!(frame.handler, 0, PointerDown({ ..down_at(12, 15), clicks: 3 }))
	fourth = Handler.dispatch!(frame.handler, 0, PointerDown({ ..down_at(12, 15), clicks: 4 }))
	new_run = Handler.dispatch!(frame.handler, 0, PointerDown(down_at(12, 15)))
	outside_new_run = Handler.dispatch!(frame.handler, 0, PointerDown(down_at(50, 50)))
	unadjusted = Interact.adjust_click_run(None, placement, child_frame)
	raw_third = Handler.dispatch!(unadjusted.handler, 0, PointerDown({ ..down_at(12, 15), clicks: 3 }))
	declining_frame : Frame(CanvasRecording.Recording(Str), U8, Interact.Events(events))
	declining_frame = Frame.from_placement_result((canvas.fill_rect!)(placement.rect, "declining"))
	reset_without_child = Handler.dispatch!((Interact.adjust_click_run(Some(adjustment), placement, declining_frame)).handler, 0, PointerDown(down_at(12, 15)))
	third == Handled(2)
		and fourth == Handled(3)
			and new_run == Handled(11)
				and outside_new_run == Handled(1)
					and raw_third == Handled(3)
						and reset_without_child == Handled(10)
							and List.len(frame.placement_result.commands) == 1
}

main! = || if frame_plus_composes_result_and_handler!() and clickable_uses_settled_rect!() and double_click_overrides_single_click_on_second_press!() and pointer_action_receives_timestamp!() and placed_pointer_filter_can_subdivide_a_widget!() and click_run_adjustment_translates_until_a_new_run!() 0 else 1
