## Interaction combinators over settled placements.
import geometry.Geometry2d
import Puri
import PuriHandler

PuriInteract := [].{

	Action(context) : context => context
	ClickFilter : U8 -> Bool

	on_primary_click : ClickFilter, Action(context) -> Puri.Widget(placed, context)
	on_primary_click = |accepts, action!| {
		|frame, placement| {
			dispatch! : PuriHandler.Dispatch(context, PuriHandler.PointerButtonEvent)
			dispatch! = |context, event| match event.button {
				Some(Primary) => if accepts(event.clicks) and Geometry2d.contains(placement.clip_rect, event.position) {
					Handled(action!(context))
				} else {
					Declined
				}
				_ => Declined
			}
			Puri.register(PuriHandler.on_pointer_down(dispatch!), frame)
		}
	}

	## Register against the visible portion of the settled node. Existing
	## placers on this node register first; descendants register later and win.
	clickable : Action(context) -> Puri.Widget(placed, context)
	clickable = |action!| PuriInteract.on_primary_click(|_clicks| Bool.True, action!)

	double_clickable : Action(context) -> Puri.Widget(placed, context)
	double_clickable = |action!| PuriInteract.on_primary_click(|clicks| clicks == 2, action!)
}
