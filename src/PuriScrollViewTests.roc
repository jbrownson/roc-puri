app [main!] { test_host: platform "../test-platform/main.roc" }

import Geometry2d
import Puri
import PuriCanvas
import PuriCanvasRecording
import PuriHandler
import PuriScrollView
import Roclay

State : { clicks : U64, focused : Bool, offset : F32 }

Recording : PuriCanvasRecording.Recording(Str)

Frame : Puri.Frame(Recording, State)

metrics : Str -> PuriCanvas.TextMetrics
metrics = |_string| { width: 0, actual_ascent: 0, actual_descent: 0, font_ascent: 0, font_descent: 0 }

canvas : PuriCanvas.Canvas(Recording, Str)
canvas = PuriCanvasRecording.canvas(metrics)

with_clip! : PuriCanvas.WithClip(Frame)
with_clip! = |frame, rect, draw!| {
	inside = draw!({ ..frame, render: PuriCanvasRecording.empty })
	clip = Clip({ rect, children: inside.render.commands })
	render = { ..frame.render, commands: List.append(frame.render.commands, clip) }
	{ ..inside, render }
}

child : Roclay.Layout(Frame)
child = Roclay.fixed(
	Geometry2d.size(50, 100),
	|frame, placement| {
		render = PuriCanvas.fill_rect!(canvas, frame.render, placement.rect, "child")
		pointer = PuriHandler.on_pointer_down(|state, _event| Handled({ ..state, clicks: state.clicks + 1 }))
		focus = PuriHandler.focusable(Bool.False, placement.rect, |state| { ..state, focused: Bool.True })
		handler = PuriHandler.combine(pointer, focus)
		Puri.register(handler, Puri.with_render(render, frame))
	},
)

place_with! : F32, Bool => Frame
place_with! = |offset, scroll_to_end| {
	config = { ..Roclay.default_box, sizing: { width: Fixed(50), height: Fixed(40) } }
	view = { offset, scroll_to_end, set_offset!: |state, next| { ..state, offset: next } }
	measured = Roclay.measure(PuriScrollView.vertical!(with_clip!, view, config, child))
	(measured.place!)(Puri.frame(PuriCanvasRecording.empty), { rect: Geometry2d.rect(10, 20, 50, 40) })
}

place! : F32 => Frame
place! = |offset| place_with!(offset, Bool.False)

scroll_event : F32 -> PuriHandler.PointerScrollEvent
scroll_event = |dy| {
	position: Geometry2d.point(15, 25),
	delta: Geometry2d.point(0, dy),
	modifiers: PuriHandler.empty_modifiers,
}

down_at : F32, F32 -> PuriHandler.PointerButtonEvent
down_at = |x, y| {
	position: Geometry2d.point(x, y),
	button: Some(Primary),
	clicks: 1,
	modifiers: PuriHandler.empty_modifiers,
}

clips_and_offsets_child! : () => Bool
clips_and_offsets_child! = || {
	frame = place!(20)
	match List.get(frame.render.commands, 0) {
		Ok(Clip(data)) => match List.get(data.children, 0) {
			Ok(FillRect(child_data)) => data.rect == Geometry2d.rect(10, 20, 50, 40) and child_data.rect == Geometry2d.rect(10, 0, 50, 100)
			_ => Bool.False
		}
		_ => Bool.False
	}
}

scroll_to_end_uses_maximum_offset! : () => Bool
scroll_to_end_uses_maximum_offset! = || {
	frame = place_with!(0, Bool.True)
	match List.get(frame.render.commands, 0) {
		Ok(Clip(data)) => match List.get(data.children, 0) {
			Ok(FillRect(child_data)) => child_data.rect.y == -40
			_ => Bool.False
		}
		_ => Bool.False
	}
}

scrolls_within_bounds! : () => Bool
scrolls_within_bounds! = || {
	frame = place!(20)
	state = { clicks: 0, focused: Bool.False, offset: 20 }
	down = PuriHandler.dispatch_scroll!(frame.handler, state, scroll_event(-1))
	up = PuriHandler.dispatch_scroll!(frame.handler, state, scroll_event(1))
	down == Handled({ clicks: 0, focused: Bool.False, offset: 60 }) and up == Handled({ clicks: 0, focused: Bool.False, offset: 0 })
}

limits_child_pointer_handler_to_viewport! : () => Bool
limits_child_pointer_handler_to_viewport! = || {
	frame = place!(20)
	state = { clicks: 0, focused: Bool.False, offset: 20 }
	inside = PuriHandler.dispatch_pointer_down!(frame.handler, state, down_at(15, 25))
	outside = PuriHandler.dispatch_pointer_down!(frame.handler, state, down_at(15, 65))
	inside == Handled({ clicks: 1, focused: Bool.False, offset: 20 }) and outside == Declined
}

keyboard_focus_reveals_child! : () => Bool
keyboard_focus_reveals_child! = || {
	frame = place!(60)
	state = { clicks: 0, focused: Bool.False, offset: 60 }
	event = { key: Named(Tab), state: KeyDown, modifiers: PuriHandler.empty_modifiers }
	PuriHandler.dispatch_key!(frame.handler, state, event) == Handled({ clicks: 0, focused: Bool.True, offset: 0 })
}

main! = || if clips_and_offsets_child!() and scroll_to_end_uses_maximum_offset!() and scrolls_within_bounds!() and limits_child_pointer_handler_to_viewport!() and keyboard_focus_reveals_child!() 0 else 1
