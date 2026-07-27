## Renderer- and layout-independent button behavior for a settled placement.
## The Description record is ephemeral input for one frame. Focus remains
## explicit application state; Puri retains neither identity nor widget state.
import geometry.Geometry2d
import Frame
import Event
import Geometry
import Handler

Button := [].{

	Action(state) : state => state
	Events(events) : [PointerDown(Event.PointerButtonEvent), Key(Event.KeyEvent), ..events]
	Content(result, state, event) : Bool, Bool, Frame.Placement => Frame(result, state, event)

	Description(result, state, event) : {
		focused : Bool,
		pointer_position : [Some(Geometry.Point), None],
		request_focus! : Action(state),
		activate! : Action(state),
		content! : Content(result, state, event),
	}

	button : Description(result, state, Events(events)) -> Frame.Widget(result, state, Events(events))
	button = |description| {
		|placement| {
			hovered = match description.pointer_position {
				Some(position) => Geometry2d.contains(placement.clip_rect, position)
				None => Bool.False
			}
			var $frame = (description.content!)(description.focused, hovered, placement)

			handle_pointer_down! : Handler.HandleEvent(state, Event.PointerButtonEvent)
			handle_pointer_down! = |state, pointer| match pointer.button {
				Some(Primary) => if Geometry2d.contains(placement.clip_rect, pointer.position) {
					focused_state = (description.request_focus!)(state)
					Handled((description.activate!)(focused_state))
				} else {
					Declined
				}
				_ => Declined
			}

			handle_key! : Handler.HandleEvent(state, Event.KeyEvent)
			handle_key! = |state, key| {
				if description.focused {
					match (key.state, key.key) {
						(KeyDown, Named(Enter)) => Handled((description.activate!)(state))
						(KeyDown, Named(Space)) => Handled((description.activate!)(state))
						_ => Declined
					}
				} else {
					Declined
				}
			}

			handle_event! : Handler.HandleEvent(state, Events(events))
			handle_event! = |state, event| match event {
				PointerDown(pointer) => handle_pointer_down!(state, pointer)
				Key(key) => handle_key!(state, key)
				_ => Declined
			}
			$frame = Frame.register(Handler.from_function(handle_event!), $frame)

			$frame
		}
	}
}
