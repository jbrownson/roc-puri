app [main!] {
	test_host: platform "../../test-platform/main.roc",
	geometry: "../../geometry/main.roc",
	roclay: "../../roclay/main.roc",
	puri: "../../puri/main.roc",
	puri_roclay: "../../puri-roclay/main.roc",
	recording: "./support/main.roc",
}

import geometry.Geometry2d
import puri.Puri
import puri.PuriButton
import puri.PuriCanvas
import recording.PuriCanvasRecording
import puri.PuriHandler
import puri_roclay.PuriRoclay
import roclay.Roclay

State : { focused : Bool, activations : U64 }

canvas : PuriCanvas.Canvas(PuriCanvasRecording.Recording(Str), Str)
canvas = PuriCanvasRecording.canvas

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

place_in! : Bool, [Some(Geometry2d.Point(F32)), None], Puri.Placement => Puri.Frame(PuriCanvasRecording.Recording(Str), State)
place_in! = |focused, pointer_position, placement| {
	content! : PuriButton.Content(PuriCanvasRecording.Recording(Str), State)
	content! = |frame, is_focused, is_hovered, content_placement| {
		paint = if is_focused "focused" else if is_hovered "hovered" else "resting"
		placed = (canvas.fill_rect!)(frame.placed, content_placement.rect, paint)
		Puri.with_placed(placed, frame)
	}
	button = { focused, pointer_position, request_focus!, activate!, content! }
	layout = PuriRoclay.decorate(PuriButton.button(button), Roclay.spacer(Geometry2d.size(20, 10)))
	measured = Roclay.measure(layout)
	(measured.place!)(Puri.frame(PuriCanvasRecording.empty), placement)
}

place! : Bool, [Some(Geometry2d.Point(F32)), None] => Puri.Frame(PuriCanvasRecording.Recording(Str), State)
place! = |focused, pointer_position| place_in!(focused, pointer_position, Geometry2d.root_placement(Geometry2d.rect(5, 7, 20, 10)))

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
	draw_matches = match List.get(frame.placed.commands, 0) {
		Ok(FillRect(data)) => data.rect == Geometry2d.rect(5, 7, 20, 10) and data.paint == "resting"
		_ => Bool.False
	}
	inside_matches and outside == Declined and secondary == Declined and List.len(frame.placed.commands) == 1 and draw_matches
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
	draw_matches = match List.get(focused_frame.placed.commands, 0) {
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
	inside_paint = match List.get(inside.placed.commands, 0) {
		Ok(FillRect(data)) => data.paint
		_ => "missing"
	}
	edge_paint = match List.get(edge.placed.commands, 0) {
		Ok(FillRect(data)) => data.paint
		_ => "missing"
	}
	outside_paint = match List.get(outside.placed.commands, 0) {
		Ok(FillRect(data)) => data.paint
		_ => "missing"
	}
	inside_paint == "hovered" and edge_paint == "hovered" and outside_paint == "resting"
}

clip_limits_hover_and_pointer_events! : () => Bool
clip_limits_hover_and_pointer_events! = || {
	placement = {
		rect: Geometry2d.rect(5, 7, 20, 10),
		clip_rect: Geometry2d.rect(5, 7, 8, 10),
	}
	clipped_out = place_in!(Bool.False, Some(Geometry2d.point(20, 10)), placement)
	visible = place_in!(Bool.False, Some(Geometry2d.point(10, 10)), placement)
	initial = { focused: Bool.False, activations: 0 }
	clipped_click = PuriHandler.dispatch_pointer_down!(clipped_out.handler, initial, button_at(20, 10, Primary))
	visible_click = PuriHandler.dispatch_pointer_down!(visible.handler, initial, button_at(10, 10, Primary))
	clipped_paint = match List.get(clipped_out.placed.commands, 0) {
		Ok(FillRect(data)) => data.paint
		_ => "missing"
	}
	visible_paint = match List.get(visible.placed.commands, 0) {
		Ok(FillRect(data)) => data.paint
		_ => "missing"
	}
	visible_matches = match visible_click {
		Handled(next) => next.focused and next.activations == 1
		Declined => Bool.False
	}
	clipped_paint == "resting" and visible_paint == "hovered" and clipped_click == Declined and visible_matches
}

main! = || if pointer_focuses_then_activates!() and only_focused_button_accepts_activation_keys!() and tab_focuses_without_activating!() and hover_uses_settled_placement!() and clip_limits_hover_and_pointer_events!() 0 else 1
