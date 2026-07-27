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
	child_frame = Frame.register(child, Frame.from_result((canvas.fill_rect!)(Geometry2d.rect(0, 0, 5, 5), "child")))
	frame = List.sum([outer_frame, child_frame])
	result = Handler.dispatch!(frame.handler, 0, PointerDown(down_at(1, 1)))
	List.len(frame.result.commands) == 1 and result == Handled(10)
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

main! = || if frame_plus_composes_result_and_handler!() and clickable_uses_settled_rect!() and double_click_overrides_single_click_on_second_press!() 0 else 1
