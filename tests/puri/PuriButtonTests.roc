app [main!] {
	test_host: platform "../../test-platform/main.roc",
	geometry: "../../geometry/main.roc",
	roclay: "../../roclay/main.roc",
	puri: "../../puri/main.roc",
	recording: "./support/main.roc",
}

import geometry.Geometry2d
import puri.Puri
import puri.PuriButton
import puri.PuriCanvas
import recording.PuriCanvasRecording
import puri.PuriHandler
import roclay.Roclay

State : { focused : Bool, activations : U64 }

metrics : Str -> PuriCanvas.TextMetrics
metrics = |_string| { width: 0, actual_ascent: 0, actual_descent: 0, font_ascent: 0, font_descent: 0 }

canvas : PuriCanvas.Canvas(PuriCanvasRecording.Recording(Str), Str)
canvas = PuriCanvasRecording.canvas(metrics)

request_focus! : State => State
request_focus! = |state| { ..state, focused: Bool.True }

activate! : State => State
activate! = |state| { ..state, activations: state.activations + 1 }

button_at : F32, F32, PuriHandler.PointerButton -> PuriHandler.PointerButtonEvent
button_at = |x, y, button| {
	position: Geometry2d.point(x, y),
	button: Some(button),
	clicks: 1,
	modifiers: PuriHandler.empty_modifiers,
}

key_down : PuriHandler.NamedKey -> PuriHandler.KeyEvent
key_down = |key| { key: Named(key), state: KeyDown, modifiers: PuriHandler.empty_modifiers }

place! : Bool, [Some(Geometry2d.Point(F32)), None] => Puri.Frame(PuriCanvasRecording.Recording(Str), State)
place! = |focused, pointer_position| {
	content! : PuriButton.Content(PuriCanvasRecording.Recording(Str), State)
	content! = |frame, is_focused, is_hovered, placement| {
		paint = if is_focused "focused" else if is_hovered "hovered" else "resting"
		render = PuriCanvas.fill_rect!(canvas, frame.render, placement.rect, paint)
		Puri.with_render(render, frame)
	}
	button = { focused, pointer_position, request_focus!, activate!, content! }
	layout = PuriButton.button!(button, Roclay.spacer(Geometry2d.size(20, 10)))
	measured = Roclay.measure(layout)
	placement = Geometry2d.root_placement(Geometry2d.rect(5, 7, 20, 10))
	(measured.place!)(Puri.frame(PuriCanvasRecording.empty), placement)
}

pointer_focuses_then_activates! : () => Bool
pointer_focuses_then_activates! = || {
	frame = place!(Bool.False, None)
	initial = { focused: Bool.False, activations: 0 }
	inside = PuriHandler.dispatch_pointer_down!(frame.handler, initial, button_at(10, 10, Primary))
	outside = PuriHandler.dispatch_pointer_down!(frame.handler, initial, button_at(40, 10, Primary))
	secondary = PuriHandler.dispatch_pointer_down!(frame.handler, initial, button_at(10, 10, Secondary))
	inside_matches = match inside {
		Handled(next) => next.focused and next.activations == 1
		Declined => Bool.False
	}
	draw_matches = match List.get(frame.render.commands, 0) {
		Ok(FillRect(data)) => data.rect == Geometry2d.rect(5, 7, 20, 10) and data.paint == "resting"
		_ => Bool.False
	}
	inside_matches and outside == Declined and secondary == Declined and List.len(frame.render.commands) == 1 and draw_matches
}

only_focused_button_accepts_activation_keys! : () => Bool
only_focused_button_accepts_activation_keys! = || {
	focused_frame = place!(Bool.True, Some(Geometry2d.point(10, 10)))
	unfocused_frame = place!(Bool.False, None)
	initial = { focused: Bool.True, activations: 3 }
	enter = PuriHandler.dispatch_key!(focused_frame.handler, initial, key_down(Enter))
	space = PuriHandler.dispatch_key!(focused_frame.handler, initial, key_down(Space))
	escape = PuriHandler.dispatch_key!(focused_frame.handler, initial, key_down(Escape))
	unfocused = PuriHandler.dispatch_key!(unfocused_frame.handler, initial, key_down(Enter))
	enter_matches = match enter {
		Handled(next) => next.activations == 4
		Declined => Bool.False
	}
	space_matches = match space {
		Handled(next) => next.activations == 4
		Declined => Bool.False
	}
	draw_matches = match List.get(focused_frame.render.commands, 0) {
		Ok(FillRect(data)) => data.paint == "focused"
		_ => Bool.False
	}
	enter_matches and space_matches and escape == Declined and unfocused == Declined and draw_matches
}

tab_focuses_without_activating! : () => Bool
tab_focuses_without_activating! = || {
	frame = place!(Bool.False, None)
	initial = { focused: Bool.False, activations: 3 }
	event = { key: Named(Tab), state: KeyDown, modifiers: PuriHandler.empty_modifiers }
	match PuriHandler.dispatch_key!(frame.handler, initial, event) {
		Handled(next) => next.focused and next.activations == 3
		Declined => Bool.False
	}
}

hover_uses_settled_placement! : () => Bool
hover_uses_settled_placement! = || {
	inside = place!(Bool.False, Some(Geometry2d.point(10, 10)))
	edge = place!(Bool.False, Some(Geometry2d.point(25, 17)))
	outside = place!(Bool.False, Some(Geometry2d.point(25.1, 17)))
	inside_paint = match List.get(inside.render.commands, 0) {
		Ok(FillRect(data)) => data.paint
		_ => "missing"
	}
	edge_paint = match List.get(edge.render.commands, 0) {
		Ok(FillRect(data)) => data.paint
		_ => "missing"
	}
	outside_paint = match List.get(outside.render.commands, 0) {
		Ok(FillRect(data)) => data.paint
		_ => "missing"
	}
	inside_paint == "hovered" and edge_paint == "hovered" and outside_paint == "resting"
}

main! = || if pointer_focuses_then_activates!() and only_focused_button_accepts_activation_keys!() and tab_focuses_without_activating!() and hover_uses_settled_placement!() 0 else 1
