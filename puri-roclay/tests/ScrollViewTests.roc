app [main!] {
	test_host: platform "./platform/main.roc",
	geometry: "../../geometry/main.roc",
	roclay: "../../roclay/main.roc",
	puri: "../../puri/main.roc",
	puri_roclay: "../main.roc",
	recording: "./support/main.roc",
}

import geometry.Geometry2d
import puri.Frame
import puri.Canvas
import puri.Event
import recording.CanvasRecording
import puri.Handler
import puri.ScrollView as PuriScrollView
import puri_roclay.ScrollView as RoclayScrollView
import roclay.Roclay

State : { clicks : U64, position : PuriScrollView.Position }

Recording : CanvasRecording.Recording(Str)

TestEvent : [
	PointerDown(Event.PointerButtonEvent),
	Scroll(Event.PointerScrollEvent),
]

TestFrame : Frame(Recording, State, TestEvent)

canvas : Canvas.Operations(Recording, Str)
canvas = CanvasRecording.canvas

with_clip! : Canvas.WithClip(TestFrame)
with_clip! = |rect, draw!| {
	inside = draw!()
	clip = Clip({ rect, children: inside.placement_result.commands })
	{ ..inside, placement_result: { commands: [clip] } }
}

child : Roclay.Layout(TestFrame)
child = Roclay.fixed(
	Geometry2d.size(50, 100),
	|placement| {
		result = (canvas.fill_rect!)(placement.rect, "child")
		pointer = Handler.from_function(
			|state, event| match event {
				PointerDown(_) => Handled({ ..state, clicks: state.clicks + 1 })
				_ => Declined
			},
		)
		Frame.register(pointer, Frame.from_placement_result(result))
	},
)

place_with! : PuriScrollView.Position => TestFrame
place_with! = |position| {
	config = { ..Roclay.default_box, sizing: { width: Fixed(50), height: Fixed(40) } }
	view = { position, set_position!: |state, next| { ..state, position: next } }
	layout = RoclayScrollView.vertical!(with_clip!, view, config, child)
	Roclay.place!(layout, Geometry2d.root_placement(Geometry2d.rect(10, 20, 50, 40)))
}

place! : F32 => TestFrame
place! = |offset| place_with!(AtOffset(offset))

scroll_event : F32 -> Event.PointerScrollEvent
scroll_event = |dy| {
	position: Geometry2d.point(15, 25),
	delta: Geometry2d.point(0, dy),
	modifiers: Event.empty_modifiers,
}

down_at : F32, F32 -> Event.PointerButtonEvent
down_at = |x, y| {
	position: Geometry2d.point(x, y),
	button: Some(Primary),
	clicks: 1,
	modifiers: Event.empty_modifiers,
}

clips_and_offsets_child! : () => Bool
clips_and_offsets_child! = || {
	frame = place!(20)
	match List.get(frame.placement_result.commands, 0) {
		Ok(Clip(data)) => match List.get(data.children, 0) {
			Ok(FillRect(child_data)) => data.rect == Geometry2d.rect(10, 20, 50, 40) and child_data.rect == Geometry2d.rect(10, 0, 50, 100)
			_ => Bool.False
		}
		_ => Bool.False
	}
}

at_end_uses_maximum_offset! : () => Bool
at_end_uses_maximum_offset! = || {
	frame = place_with!(AtEnd)
	match List.get(frame.placement_result.commands, 0) {
		Ok(Clip(data)) => match List.get(data.children, 0) {
			Ok(FillRect(child_data)) => child_data.rect.y == -40
			_ => Bool.False
		}
		_ => Bool.False
	}
}

scrolling_from_end_selects_an_offset! : () => Bool
scrolling_from_end_selects_an_offset! = || {
	frame = place_with!(AtEnd)
	state = { clicks: 0, position: AtEnd }
	Handler.dispatch!(frame.handler, state, Scroll(scroll_event(40))) == Handled({ clicks: 0, position: AtOffset(20) })
}

scrolls_within_bounds! : () => Bool
scrolls_within_bounds! = || {
	frame = place!(20)
	state = { clicks: 0, position: AtOffset(20) }
	down = Handler.dispatch!(frame.handler, state, Scroll(scroll_event(-40)))
	up = Handler.dispatch!(frame.handler, state, Scroll(scroll_event(40)))
	down == Handled({ clicks: 0, position: AtOffset(60) }) and up == Handled({ clicks: 0, position: AtOffset(0) })
}

limits_child_pointer_handler_to_viewport! : () => Bool
limits_child_pointer_handler_to_viewport! = || {
	frame = place!(20)
	state = { clicks: 0, position: AtOffset(20) }
	inside = Handler.dispatch!(frame.handler, state, PointerDown(down_at(15, 25)))
	outside = Handler.dispatch!(frame.handler, state, PointerDown(down_at(15, 65)))
	inside == Handled({ clicks: 1, position: AtOffset(20) }) and outside == Declined
}

main! = || if clips_and_offsets_child!() and at_end_uses_maximum_offset!() and scrolling_from_end_selects_an_offset!() and scrolls_within_bounds!() and limits_child_pointer_handler_to_viewport!() 0 else 1
