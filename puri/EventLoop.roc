## Consume a batch of platform events without reusing a one-shot Puri handler.
## Every event receives a frame freshly built from the state produced by the
## previous event. Only the final event's frame is marked visible; the builder
## uses a silent interpreter for the preceding frames. An empty batch still
## renders one frame.
import Frame
import Handler

EventLoop := [].{

	Visibility := [Silent, Visible]

	BuildFrame(placement_result, state, event) : state, Visibility => Frame(placement_result, state, event)

	run! : List(event), state, BuildFrame(placement_result, state, event) => state
	run! = |events, initial_state, build_frame!| {
		if List.is_empty(events) {
			_ = build_frame!(initial_state, Visible)
			initial_state
		} else {
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
}
