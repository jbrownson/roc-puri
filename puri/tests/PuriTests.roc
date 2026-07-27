app [main!] {
	test_host: platform "./platform/main.roc",
	geometry: "../../geometry/main.roc",
	roclay: "../../roclay/main.roc",
	puri: "../main.roc",
	puri_roclay: "../roclay/main.roc",
	recording: "./support/main.roc",
}

import geometry.Geometry2d
import puri.Puri
import puri.PuriCanvas
import recording.PuriCanvasRecording
import puri.PuriHandler
import puri.PuriInteract
import puri_roclay.PuriRoclay
import roclay.Roclay

down_at : F32, F32 -> PuriHandler.PointerButtonEvent
down_at = |x, y| {
	position: Geometry2d.point(x, y),
	button: Some(Primary),
	clicks: 1,
	modifiers: PuriHandler.empty_modifiers,
}

double_down_at : F32, F32 -> PuriHandler.PointerButtonEvent
double_down_at = |x, y| { ..down_at(x, y), clicks: 2 }

frame_plus_composes_result_and_handler! : () => Bool
frame_plus_composes_result_and_handler! = || {
	canvas : PuriCanvas.Canvas(PuriCanvasRecording.Recording(Str), Str)
	canvas = PuriCanvasRecording.canvas
	outer = PuriHandler.on_pointer_down(|value, _event| Handled(value + 1))
	child = PuriHandler.on_pointer_down(|value, _event| Handled(value + 10))
	empty_frame : Puri.Frame(PuriCanvasRecording.Recording(Str), U64)
	empty_frame = Puri.Frame.default()
	outer_frame = Puri.register(outer, empty_frame)
	child_frame = Puri.register(child, Puri.frame((canvas.fill_rect!)(Geometry2d.rect(0, 0, 5, 5), "child")))
	frame = List.sum([outer_frame, child_frame])
	result = PuriHandler.dispatch_pointer_down!(frame.handler, 0, down_at(1, 1))
	List.len(frame.result.commands) == 1 and result == Handled(10)
}

clickable_uses_settled_rect! : () => Bool
clickable_uses_settled_rect! = || {
	layout : Roclay.Layout(Puri.Frame(PuriCanvasRecording.Recording(Str), U64))
	layout = PuriRoclay.decorate(
		PuriInteract.clickable(|value| value + 1),
		Roclay.spacer(Geometry2d.size(20, 10)),
	)
	measured = Roclay.measure(layout)
	placement = Geometry2d.root_placement(Geometry2d.rect(10, 10, 20, 10))
	frame = (measured.place!)(placement)
	outside = PuriHandler.dispatch_pointer_down!(frame.handler, 0, down_at(9, 15))
	inside = PuriHandler.dispatch_pointer_down!(frame.handler, 0, down_at(12, 15))
	outside == Declined and inside == Handled(1)
}

double_click_overrides_single_click_on_second_press! : () => Bool
double_click_overrides_single_click_on_second_press! = || {
	clickable : Roclay.Layout(Puri.Frame(PuriCanvasRecording.Recording(Str), U64))
	clickable = PuriRoclay.decorate(
		PuriInteract.clickable(|value| value + 1),
		Roclay.spacer(Geometry2d.size(20, 10)),
	)
	layout : Roclay.Layout(Puri.Frame(PuriCanvasRecording.Recording(Str), U64))
	layout = PuriRoclay.decorate(
		PuriInteract.double_clickable(|value| value + 10),
		clickable,
	)
	measured = Roclay.measure(layout)
	frame = (measured.place!)(Geometry2d.root_placement(Geometry2d.rect(10, 10, 20, 10)))
	single = PuriHandler.dispatch_pointer_down!(frame.handler, 0, down_at(12, 15))
	double = PuriHandler.dispatch_pointer_down!(frame.handler, 0, double_down_at(12, 15))
	single == Handled(1) and double == Handled(10)
}

main! = || if frame_plus_composes_result_and_handler!() and clickable_uses_settled_rect!() and double_click_overrides_single_click_on_second_press!() 0 else 1
