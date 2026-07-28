## Consume a batch of platform events without reusing a one-shot Puri handler.
## Every event receives a frame freshly built from the state produced by the
## previous event. Only the final event's frame is marked visible; the builder
## uses a silent interpreter for the preceding frames. An empty input batch
## receives one TimePassed event carrying the current frame timestamp.
import Event
import Frame
import Handler

EventLoop := [].{

	Visibility := [Silent, Visible]

	BuildFrame(placement_result, state, additional_events) : state, Visibility => Frame(placement_result, state, Event.Events(additional_events))

	run! : List(Event.Events(additional_events)), U64, state, BuildFrame(placement_result, state, additional_events) => state
	run! = |input_events, timestamp_nanos, initial_state, build_frame!| {
		events = if List.is_empty(input_events) {
			[
				TimePassed({
					timestamp_nanos,
				}),
			]
		} else {
			input_events
		}
		last_index = List.len(events) - 1
		var $state = initial_state
		var $index = 0
		for event in events {
			visibility = if $index == last_index {
				Visible
			} else {
				Silent
			}
			handler = build_frame!($state, visibility).handler
			$state = match Handler.dispatch!(handler, $state, event) {
				Handled(next) => next
				Declined => $state
			}
			$index = $index + 1
		}
		$state
	}
}
