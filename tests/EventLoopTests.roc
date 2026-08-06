app [main!] {
	test_host: platform "./platform/main.roc",
	geometry: "https://github.com/jbrownson/roc-puri-geometry/releases/download/0.1.0/8YcrEeY7J3K9khuA2ULAcMZvzAbqPzdT9qKCDX9YvqSP.tar.zst",
	puri: "../main.roc",
	recording: "./support/main.roc",
}

import puri.EventLoop
import puri.Event
import puri.Frame
import puri.Handler
import recording.CanvasRecording

Events : Event.Events([Advance])

TestFrame : Frame(CanvasRecording.Recording(Str), U64, Events)

frame_adding : U64, U64 -> TestFrame
frame_adding = |built_state, amount| {
	handler = Handler.from_function(
		|_state, event| match event {
			Advance => Handled(built_state + amount)
			TimePassed({ timestamp_nanos }) => Handled(built_state + timestamp_nanos)
			_ => Declined
		},
	)
	Frame.register(handler, Frame.default())
}

build! : EventLoop.BuildFrame(CanvasRecording.Recording(Str), U64, [Advance])
build! = |state, visibility| {
	amount = match visibility {
		Silent => 1
		Visible => 10
	}
	frame_adding(state, amount)
}

single_event_has_no_intermediate_frame! : () => Bool
single_event_has_no_intermediate_frame! = || EventLoop.run!([Advance], 100, 0, build!) == 10

each_event_gets_a_fresh_frame! : () => Bool
each_event_gets_a_fresh_frame! = || {
	EventLoop.run!([Advance, Advance, Advance], 100, 0, build!) == 12
}

empty_batch_receives_time_passed! : () => Bool
empty_batch_receives_time_passed! = || EventLoop.run!([], 7, 0, build!) == 7

main! = || if single_event_has_no_intermediate_frame!() and each_event_gets_a_fresh_frame!() and empty_batch_receives_time_passed!() 0 else 1
