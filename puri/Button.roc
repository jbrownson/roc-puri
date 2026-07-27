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
	ContentDescription : {
		focused : Bool,
		hovered : Bool,
		placement : Frame.Placement,
	}
	Content(result, state, event) : ContentDescription => Frame(result, state, event)

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
			frame = (description.content!)({
				focused: description.focused,
				hovered,
				placement,
			})

			handle_event! : Handler.HandleEvent(state, Events(events))
			handle_event! = |state, event| match event {
				PointerDown({ button: Some(Primary), position, .. }) if Geometry2d.contains(placement.clip_rect, position) => {
					focused_state = (description.request_focus!)(state)
					Handled((description.activate!)(focused_state))
				}
				Key({ state: KeyDown, key: Named(Enter), .. }) | Key({ state: KeyDown, key: Named(Space), .. }) if description.focused => Handled((description.activate!)(state))
				_ => Declined
			}
			Frame.register(Handler.from_function(handle_event!), frame)
		}
	}
}
