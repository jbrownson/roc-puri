app [main!] {
	test_host: platform "../../test-platform/main.roc",
	geometry: "../../geometry/main.roc",
	roclay: "../../roclay/main.roc",
	puri: "../../puri/main.roc",
	recording: "./support/main.roc",
}

import geometry.Geometry2d
import puri.Puri
import puri.PuriCanvas
import recording.PuriCanvasRecording
import puri.PuriHandler
import puri.PuriInteract
import roclay.Roclay

metrics : Str -> PuriCanvas.TextMetrics
metrics = |_string| { width: 0, actual_ascent: 0, actual_descent: 0, font_ascent: 0, font_descent: 0 }

down_at : F32, F32 -> PuriHandler.PointerButtonEvent
down_at = |x, y| {
	position: Geometry2d.point(x, y),
	button: Some(Primary),
	clicks: 1,
	modifiers: PuriHandler.empty_modifiers,
}

double_down_at : F32, F32 -> PuriHandler.PointerButtonEvent
double_down_at = |x, y| { ..down_at(x, y), clicks: 2 }

capture_preserves_render_and_scopes_handler! : () => Bool
capture_preserves_render_and_scopes_handler! = || {
	canvas : PuriCanvas.Canvas(PuriCanvasRecording.Recording(Str), Str)
	canvas = PuriCanvasRecording.canvas(metrics)
	outer = PuriHandler.on_pointer_down(|value, _event| Handled(value + 1))
	start = Puri.register(outer, Puri.frame(PuriCanvasRecording.empty))
	captured = Puri.capture!(
		start,
		|inner| {
			render = PuriCanvas.fill_rect!(canvas, inner.render, Geometry2d.rect(0, 0, 5, 5), "child")
			child = PuriHandler.on_pointer_down(|value, _event| Handled(value + 10))
			Puri.register(child, Puri.with_render(render, inner))
		},
	)
	outer_result = PuriHandler.dispatch_pointer_down!(captured.frame.handler, 0, down_at(1, 1))
	child_result = PuriHandler.dispatch_pointer_down!(captured.captured, 0, down_at(1, 1))
	List.len(captured.frame.render.commands) == 1 and outer_result == Handled(1) and child_result == Handled(10)
}

clickable_uses_settled_rect! : () => Bool
clickable_uses_settled_rect! = || {
	layout = PuriInteract.clickable(
		|value| value + 1,
		Roclay.fixed(Geometry2d.size(20, 10), |frame, _placement| frame),
	)
	measured = Roclay.measure(layout)
	placement = { rect: Geometry2d.rect(10, 10, 20, 10) }
	frame = (measured.place!)(Puri.frame({}), placement)
	outside = PuriHandler.dispatch_pointer_down!(frame.handler, 0, down_at(9, 15))
	inside = PuriHandler.dispatch_pointer_down!(frame.handler, 0, down_at(12, 15))
	outside == Declined and inside == Handled(1)
}

double_click_overrides_single_click_on_second_press! : () => Bool
double_click_overrides_single_click_on_second_press! = || {
	clickable = PuriInteract.clickable(
		|value| value + 1,
		Roclay.fixed(Geometry2d.size(20, 10), |frame, _placement| frame),
	)
	layout = PuriInteract.double_clickable(
		|value| value + 10,
		clickable,
	)
	measured = Roclay.measure(layout)
	frame = (measured.place!)(Puri.frame({}), { rect: Geometry2d.rect(10, 10, 20, 10) })
	single = PuriHandler.dispatch_pointer_down!(frame.handler, 0, down_at(12, 15))
	double = PuriHandler.dispatch_pointer_down!(frame.handler, 0, double_down_at(12, 15))
	single == Handled(1) and double == Handled(10)
}

main! = || if capture_preserves_render_and_scopes_handler!() and clickable_uses_settled_rect!() and double_click_overrides_single_click_on_second_press!() 0 else 1
