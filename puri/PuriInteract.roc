## Interaction combinators over Roclay's settled placements.
import geometry.Geometry2d
import Puri
import PuriHandler
import roclay.Roclay

PuriInteract := [].{

	Action(context) : context => context
	ClickFilter : U8 -> Bool

	on_primary_click : ClickFilter, Action(context), Roclay.Layout(Puri.Frame(render, context)) -> Roclay.Layout(Puri.Frame(render, context))
	on_primary_click = |accepts, action!, layout| Roclay.decorate(
		|frame, placement| {
			dispatch! : PuriHandler.Dispatch(context, PuriHandler.PointerButtonEvent)
			dispatch! = |context, event| match event.button {
				Some(Primary) => if accepts(event.clicks) and Geometry2d.contains(placement.rect, event.position) {
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

	## Register against the settled node rectangle. Existing placers on this
	## node register first; descendant widgets register later and still win.
	clickable : Action(context), Roclay.Layout(Puri.Frame(render, context)) -> Roclay.Layout(Puri.Frame(render, context))
	clickable = |action!, layout| PuriInteract.on_primary_click(|_clicks| Bool.True, action!, layout)

	double_clickable : Action(context), Roclay.Layout(Puri.Frame(render, context)) -> Roclay.Layout(Puri.Frame(render, context))
	double_clickable = |action!, layout| PuriInteract.on_primary_click(|clicks| clicks == 2, action!, layout)
}
