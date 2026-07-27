app [main!] {
	test_host: platform "../../test-platform/main.roc",
	geometry: "../../geometry/main.roc",
	roclay: "../../roclay/main.roc",
	puri: "../../puri/main.roc",
	puri_roclay: "../../puri-roclay/main.roc",
	recording: "../puri/support/main.roc",
}

import geometry.Geometry2d
import puri.Puri
import puri.PuriCanvas
import recording.PuriCanvasRecording
import puri.PuriHandler
import puri_roclay.PuriScrollView
import roclay.Roclay

State : { clicks : U64, focused : Bool, offset : F32 }

Recording : PuriCanvasRecording.Recording(Str)

Frame : Puri.Frame(Recording, State)

canvas : PuriCanvas.Canvas(Recording, Str)
canvas = PuriCanvasRecording.canvas

with_clip! : PuriCanvas.WithClip(Frame)
with_clip! = |rect, draw!| {
	inside = draw!()
	clip = Clip({ rect, children: inside.result.commands })
	{ ..inside, result: { commands: [clip] } }
}

child : Roclay.Layout(Frame)
child = Roclay.fixed(
	Geometry2d.size(50, 100),
	|placement| {
		result = (canvas.fill_rect!)(placement.rect, "child")
		pointer = PuriHandler.on_pointer_down(|state, _event| Handled({ ..state, clicks: state.clicks + 1 }))
		focus = PuriHandler.focusable(Bool.False, placement.rect, |state| { ..state, focused: Bool.True })
		handler = pointer + focus
		Puri.register(handler, Puri.frame(result))
	},
)

place_with! : F32, Bool => Frame
place_with! = |offset, scroll_to_end| {
	config = { ..Roclay.default_box, sizing: { width: Fixed(50), height: Fixed(40) } }
	view = { offset, scroll_to_end, set_offset!: |state, next| { ..state, offset: next } }
	measured = Roclay.measure(PuriScrollView.vertical!(with_clip!, view, config, child))
	(measured.place!)(Geometry2d.root_placement(Geometry2d.rect(10, 20, 50, 40)))
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
	match List.get(frame.result.commands, 0) {
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
	match List.get(frame.result.commands, 0) {
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
	down = PuriHandler.dispatch_scroll!(frame.handler, state, scroll_event(-40))
	up = PuriHandler.dispatch_scroll!(frame.handler, state, scroll_event(40))
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
