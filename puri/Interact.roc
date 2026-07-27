## Interaction combinators over settled placements.
import geometry.Geometry2d
import Frame
import Event
import Handler

Interact := [].{

	Action(state) : state => state
	ClickFilter : U8 -> Bool
	Events(events) : [PointerDown(Event.PointerButtonEvent), ..events]

	on_primary_click : ClickFilter, Action(state) -> Frame.Widget(result, state, Events(events))
		where [result.default : result]
	on_primary_click = |accepts, action!| {
		|placement| {
			handle_event! : Handler.HandleEvent(state, Events(events))
			handle_event! = |state, event| match event {
				PointerDown({ button: Some(Primary), clicks, position, .. }) => {
					if accepts(clicks) and Geometry2d.contains(placement.clip_rect, position) {
						Handled(action!(state))
					} else {
						Declined
					}
				}
				_ => Declined
			}
			Frame.register(Handler.from_function(handle_event!), Frame.default())
		}
	}

	## Register against the visible portion of the settled node. Existing
	## placers on this node register first; descendants register later and win.
	clickable : Action(state) -> Frame.Widget(result, state, Events(events))
		where [result.default : result]
	clickable = |action!| Interact.on_primary_click(|_clicks| Bool.True, action!)

	double_clickable : Action(state) -> Frame.Widget(result, state, Events(events))
		where [result.default : result]
	double_clickable = |action!| Interact.on_primary_click(|clicks| clicks == 2, action!)
}
