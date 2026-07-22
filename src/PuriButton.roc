## A renderer-independent button interaction wrapped around any Roclay content.
## The Button record is an ephemeral description for one frame. Focus remains
## explicit application state; Puri retains neither identity nor widget state.
import Geometry2d
import Puri
import PuriHandler
import Roclay

PuriButton := [].{

	Action(context) : context => context
	Content(render, context) : Puri.Frame(render, context), Bool, Puri.Placement => Puri.Frame(render, context)

	Button(render, context) : {
		focused : Bool,
		request_focus! : Action(context),
		activate! : Action(context),
		content! : Content(render, context),
	}

	button! : Button(render, context), Roclay.Layout(Puri.Frame(render, context)) -> Roclay.Layout(Puri.Frame(render, context))
	button! = |button, layout| Roclay.decorate(
		|initial_frame, placement| {
			var $frame = (button.content!)(initial_frame, button.focused, placement)

			pointer_down! : PuriHandler.Dispatch(context, PuriHandler.PointerButtonEvent)
			pointer_down! = |context, event| match event.button {
				Some(Primary) => if Geometry2d.contains(placement.rect, event.position) {
					focused_context = (button.request_focus!)(context)
					Handled((button.activate!)(focused_context))
				} else {
					Declined
				}
				_ => Declined
			}
			$frame = Puri.register(PuriHandler.on_pointer_down(pointer_down!), $frame)

			if button.focused {
				key! : PuriHandler.Dispatch(context, PuriHandler.KeyEvent)
				key! = |context, event| match (event.state, event.key) {
					(KeyDown, Named(Enter)) => Handled((button.activate!)(context))
					(KeyDown, Named(Space)) => Handled((button.activate!)(context))
					_ => Declined
				}
				$frame = Puri.register(PuriHandler.on_key(key!), $frame)
			}

			$frame
		},
		layout,
	)
}
