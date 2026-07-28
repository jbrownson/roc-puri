## Layout-independent routing for drag gestures.
##
## These invisible widgets retain no gesture state. The caller decides when a
## drag is active and supplies the state transitions run for pointer events.
import geometry.Geometry2d
import Frame
import Event
import Handler

Drag := [].{

	Begin(state) : state, Frame.Placement, Event.PointerButtonEvent => state
	Move(state) : state, Frame.Placement, Event.PointerMoveEvent => Handler.HandleResult(state)
	Finish(state) : state, Frame.Placement, Event.PointerButtonEvent => state

	SourceEvents(events) : [PointerDown(Event.PointerButtonEvent), ..events]
	MoveEvents(events) : [PointerMove(Event.PointerMoveEvent), ..events]
	ReleaseEvents(events) : [PointerUp(Event.PointerButtonEvent), ..events]
	Events(events) : [PointerDown(Event.PointerButtonEvent), PointerMove(Event.PointerMoveEvent), PointerUp(Event.PointerButtonEvent), ..events]

	source : Bool, Begin(state) -> Frame.Widget(result, state, SourceEvents(events))
		where [result.default : result]
	source = |enabled, begin!| {
		|placement| {
			handle_event! : Handler.HandleEvent(state, SourceEvents(events))
			handle_event! = |state, event| match event {
				PointerDown(pointer) => match pointer.button {
					Some(Primary) if enabled and Geometry2d.contains(placement.clip_rect, pointer.position) => Handled(begin!(state, placement, pointer))
					_ => Declined
				}
				_ => Declined
			}
			Frame.register(Handler.from_function(handle_event!), Frame.default())
		}
	}

	motion : Bool, Move(state) -> Frame.Widget(result, state, MoveEvents(events))
		where [result.default : result]
	motion = |enabled, move!| {
		|placement| {
			handle_event! : Handler.HandleEvent(state, MoveEvents(events))
			handle_event! = |state, event| match event {
				PointerMove(pointer) if enabled => move!(state, placement, pointer)
				_ => Declined
			}
			Frame.register(Handler.from_function(handle_event!), Frame.default())
		}
	}

	release : Bool, Finish(state) -> Frame.Widget(result, state, ReleaseEvents(events))
		where [result.default : result]
	release = |enabled, finish!| {
		|placement| {
			handle_event! : Handler.HandleEvent(state, ReleaseEvents(events))
			handle_event! = |state, event| match event {
				PointerUp(pointer) => match pointer.button {
					Some(Primary) if enabled => Handled(finish!(state, placement, pointer))
					_ => Declined
				}
				_ => Declined
			}
			Frame.register(Handler.from_function(handle_event!), Frame.default())
		}
	}
}
