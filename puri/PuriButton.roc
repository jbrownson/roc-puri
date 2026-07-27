## Renderer- and layout-independent button behavior for a settled placement.
## The Button record is an ephemeral description for one frame. Focus remains
## explicit application state; Puri retains neither identity nor widget state.
import geometry.Geometry2d
import Puri
import PuriEvent
import PuriHandler

PuriButton := [].{

	Action(state) : state => state
	Events(events) : [PointerDown(PuriEvent.PointerButtonEvent), Key(PuriEvent.KeyEvent), ..events]
	Content(result, state, event) : Bool, Bool, Puri.Placement => Puri.Frame(result, state, event)

	Button(result, state, event) : {
		focused : Bool,
		pointer_position : [Some(Geometry2d.Point(F32)), None],
		request_focus! : Action(state),
		activate! : Action(state),
		content! : Content(result, state, event),
	}

	button : Button(result, state, Events(events)) -> Puri.Widget(result, state, Events(events))
	button = |description| {
		|placement| {
			hovered = match description.pointer_position {
				Some(position) => Geometry2d.contains(placement.clip_rect, position)
				None => Bool.False
			}
			var $frame = (description.content!)(description.focused, hovered, placement)

			handle_pointer_down! : PuriHandler.HandleEvent(state, PuriEvent.PointerButtonEvent)
			handle_pointer_down! = |state, pointer| match pointer.button {
				Some(Primary) => if Geometry2d.contains(placement.clip_rect, pointer.position) {
					focused_state = (description.request_focus!)(state)
					Handled((description.activate!)(focused_state))
				} else {
					Declined
				}
				_ => Declined
			}

			handle_key! : PuriHandler.HandleEvent(state, PuriEvent.KeyEvent)
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

			handle_event! : PuriHandler.HandleEvent(state, Events(events))
			handle_event! = |state, event| match event {
				PointerDown(pointer) => handle_pointer_down!(state, pointer)
				Key(key) => handle_key!(state, key)
				_ => Declined
			}
			$frame = Puri.register(PuriHandler.on_event(handle_event!), $frame)
			$frame = Puri.register(
				PuriHandler.focusable(description.focused, placement.rect, description.request_focus!),
				$frame,
			)

			$frame
		}
	}
}
