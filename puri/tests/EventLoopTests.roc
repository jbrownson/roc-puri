app [main!] {
	test_host: platform "./platform/main.roc",
	geometry: "../../geometry/main.roc",
	puri: "../main.roc",
	recording: "./support/main.roc",
}

import puri.EventLoop
import puri.Frame
import puri.Handler
import recording.CanvasRecording

Event : [Advance]

TestFrame : Frame(CanvasRecording.Recording(Str), U64, Event)

frame_adding : U64, U64 -> TestFrame
frame_adding = |built_state, amount| {
	handler = Handler.from_function(|_state, Advance| Handled(built_state + amount))
	Frame.register(handler, Frame.default())
}

build! : EventLoop.BuildFrame(CanvasRecording.Recording(Str), U64, Event)
build! = |state, visibility| {
	amount = match visibility {
		Silent => 1
		Visible => 10
	}
	frame_adding(state, amount)
}

single_event_has_no_intermediate_frame! : () => Bool
single_event_has_no_intermediate_frame! = || EventLoop.run!([Advance], 0, build!) == 10

each_event_gets_a_fresh_frame! : () => Bool
each_event_gets_a_fresh_frame! = || {
	EventLoop.run!([Advance, Advance, Advance], 0, build!) == 12
}

empty_batch_preserves_state! : () => Bool
empty_batch_preserves_state! = || EventLoop.run!([], 7, build!) == 7

main! = || if single_event_has_no_intermediate_frame!() and each_event_gets_a_fresh_frame!() and empty_batch_preserves_state!() 0 else 1
