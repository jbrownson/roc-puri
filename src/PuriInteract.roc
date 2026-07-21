## Interaction combinators over Roclay's settled placements.
import Geometry2d
import Puri
import PuriHandler
import Roclay

PuriInteract := [].{

	Action(context) : context => context

	## Register a primary-button action for the node's visible placement. The
	## decorator registers before the subtree places, so deeper widgets compose
	## later and receive the event first.
	clickable : Action(context), Roclay.Layout(Puri.Frame(render, context)) -> Roclay.Layout(Puri.Frame(render, context))
	clickable = |action!, layout| Roclay.decorate(
		|frame, placement| {
			dispatch! : PuriHandler.Dispatch(context, PuriHandler.PointerButtonEvent)
			dispatch! = |context, event| match event.button {
				Some(Primary) => if Geometry2d.contains(placement.clip_rect, event.position) {
					Handled(action!(context))
				} else {
					Declined
				}
				_ => Declined
			}
			Puri.register(PuriHandler.on_pointer_down(dispatch!), frame)
		},
		layout,
	)
}
