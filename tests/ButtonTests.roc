app [main!] {
	test_host: platform "./platform/main.roc",
	geometry: "https://github.com/jbrownson/roc-puri-geometry/releases/download/0.1.0/8YcrEeY7J3K9khuA2ULAcMZvzAbqPzdT9qKCDX9YvqSP.tar.zst",
	puri: "../main.roc",
	recording: "./support/main.roc",
}

import geometry.Geometry2d
import puri.Frame
import puri.Button
import puri.Canvas
import puri.Event
import recording.CanvasRecording
import puri.Handler

State : { focused : Bool, activations : U64 }

canvas : Canvas.Operations(CanvasRecording.Recording(Str), Str)
canvas = CanvasRecording.canvas

request_focus! : State => State
request_focus! = |state| { ..state, focused: Bool.True }

activate! : State => State
activate! = |state| { ..state, activations: state.activations + 1 }

button_at : F32, F32, Event.PointerButton -> Event.PointerButtonEvent
button_at = |x, y, button| {
	timestamp_nanos: 0,
	position: Geometry2d.point(x, y),
	button: Some(button),
	clicks: 1,
	modifiers: Event.empty_modifiers,
}

key_down : Event.NamedKey -> Event.KeyEvent
key_down = |key| { timestamp_nanos: 0, key: Named(key), state: KeyDown, modifiers: Event.empty_modifiers }

place_in! : Bool, [Some(Geometry2d.Point(F32)), None], Frame.Placement => Frame(CanvasRecording.Recording(Str), State, Button.Events(events))
place_in! = |focused, pointer_position, placement| {
	content! : Button.Content(CanvasRecording.Recording(Str), State, Button.Events(events))
	content! = |content| {
		paint = if content.focused "focused" else if content.hovered "hovered" else "resting"
		Frame.from_placement_result((canvas.fill_rect!)(content.placement.rect, paint))
	}
	button = { focused, pointer_position, request_focus!, activate!, content! }
	(Button.button(button))(placement)
}

place! : Bool, [Some(Geometry2d.Point(F32)), None] => Frame(CanvasRecording.Recording(Str), State, Button.Events(events))
place! = |focused, pointer_position| place_in!(focused, pointer_position, Geometry2d.root_placement(Geometry2d.rect(5, 7, 20, 10)))

pointer_focuses_then_activates! : () => Bool
pointer_focuses_then_activates! = || {
	frame = place!(Bool.False, None)
	initial = { focused: Bool.False, activations: 0 }
	inside = Handler.dispatch!(frame.handler, initial, PointerDown(button_at(10, 10, Primary)))
	outside = Handler.dispatch!(frame.handler, initial, PointerDown(button_at(40, 10, Primary)))
	secondary = Handler.dispatch!(frame.handler, initial, PointerDown(button_at(10, 10, Secondary)))
	inside_matches = match inside {
		Handled(next) => next.focused and next.activations == 1
		Declined => Bool.False
	}
	draw_matches = match List.get(frame.placement_result.commands, 0) {
		Ok(FillRect(data)) => data.rect == Geometry2d.rect(5, 7, 20, 10) and data.paint == "resting"
		_ => Bool.False
	}
	inside_matches and outside == Declined and secondary == Declined and List.len(frame.placement_result.commands) == 1 and draw_matches
}

only_focused_button_accepts_activation_keys! : () => Bool
only_focused_button_accepts_activation_keys! = || {
	focused_frame = place!(Bool.True, Some(Geometry2d.point(10, 10)))
	unfocused_frame = place!(Bool.False, None)
	initial = { focused: Bool.True, activations: 3 }
	enter = Handler.dispatch!(focused_frame.handler, initial, Key(key_down(Enter)))
	space = Handler.dispatch!(focused_frame.handler, initial, Key(key_down(Space)))
	escape = Handler.dispatch!(focused_frame.handler, initial, Key(key_down(Escape)))
	unfocused = Handler.dispatch!(unfocused_frame.handler, initial, Key(key_down(Enter)))
	enter_matches = match enter {
		Handled(next) => next.activations == 4
		Declined => Bool.False
	}
	space_matches = match space {
		Handled(next) => next.activations == 4
		Declined => Bool.False
	}
	draw_matches = match List.get(focused_frame.placement_result.commands, 0) {
		Ok(FillRect(data)) => data.paint == "focused"
		_ => Bool.False
	}
	enter_matches and space_matches and escape == Declined and unfocused == Declined and draw_matches
}

hover_uses_settled_placement! : () => Bool
hover_uses_settled_placement! = || {
	inside = place!(Bool.False, Some(Geometry2d.point(10, 10)))
	edge = place!(Bool.False, Some(Geometry2d.point(25, 17)))
	outside = place!(Bool.False, Some(Geometry2d.point(25.1, 17)))
	inside_paint = match List.get(inside.placement_result.commands, 0) {
		Ok(FillRect(data)) => data.paint
		_ => "missing"
	}
	edge_paint = match List.get(edge.placement_result.commands, 0) {
		Ok(FillRect(data)) => data.paint
		_ => "missing"
	}
	outside_paint = match List.get(outside.placement_result.commands, 0) {
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
	clipped_click = Handler.dispatch!(clipped_out.handler, initial, PointerDown(button_at(20, 10, Primary)))
	visible_click = Handler.dispatch!(visible.handler, initial, PointerDown(button_at(10, 10, Primary)))
	clipped_paint = match List.get(clipped_out.placement_result.commands, 0) {
		Ok(FillRect(data)) => data.paint
		_ => "missing"
	}
	visible_paint = match List.get(visible.placement_result.commands, 0) {
		Ok(FillRect(data)) => data.paint
		_ => "missing"
	}
	visible_matches = match visible_click {
		Handled(next) => next.focused and next.activations == 1
		Declined => Bool.False
	}
	clipped_paint == "resting" and visible_paint == "hovered" and clipped_click == Declined and visible_matches
}

main! = || if pointer_focuses_then_activates!() and only_focused_button_accepts_activation_keys!() and hover_uses_settled_placement!() and clip_limits_hover_and_pointer_events!() 0 else 1
