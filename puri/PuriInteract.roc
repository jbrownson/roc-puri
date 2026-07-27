## Interaction combinators over settled placements.
import geometry.Geometry2d
import Puri
import PuriEvent
import PuriHandler

PuriInteract := [].{

	Action(state) : state => state
	ClickFilter : U8 -> Bool
	Events(events) : [PointerDown(PuriEvent.PointerButtonEvent), ..events]

	on_primary_click : ClickFilter, Action(state) -> Puri.Widget(result, state, Events(events))
		where [result.default : result]
	on_primary_click = |accepts, action!| {
		|placement| {
			handle_event! : PuriHandler.HandleEvent(state, Events(events))
			handle_event! = |state, event| match event {
				PointerDown(pointer) => match pointer.button {
					Some(Primary) => if accepts(pointer.clicks) and Geometry2d.contains(placement.clip_rect, pointer.position) {
						Handled(action!(state))
					} else {
						Declined
					}
					_ => Declined
				}
				_ => Declined
			}
			Puri.register(PuriHandler.on_event(handle_event!), Puri.Frame.default())
		}
	}

	## Register against the visible portion of the settled node. Existing
	## placers on this node register first; descendants register later and win.
	clickable : Action(state) -> Puri.Widget(result, state, Events(events))
		where [result.default : result]
	clickable = |action!| PuriInteract.on_primary_click(|_clicks| Bool.True, action!)

	double_clickable : Action(state) -> Puri.Widget(result, state, Events(events))
		where [result.default : result]
	double_clickable = |action!| PuriInteract.on_primary_click(|clicks| clicks == 2, action!)
}
