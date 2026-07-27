## Renderer- and layout-independent button behavior for a settled placement.
## The Button record is an ephemeral description for one frame. Focus remains
## explicit application state; Puri retains neither identity nor widget state.
import geometry.Geometry2d
import Puri
import PuriHandler

PuriButton := [].{

	Action(context) : context => context
	Content(result, context) : Bool, Bool, Puri.Placement => Puri.Frame(result, context)

	Button(result, context) : {
		focused : Bool,
		pointer_position : [Some(Geometry2d.Point(F32)), None],
		request_focus! : Action(context),
		activate! : Action(context),
		content! : Content(result, context),
	}

	button : Button(result, context) -> Puri.Widget(result, context)
	button = |description| {
		|placement| {
			hovered = match description.pointer_position {
				Some(position) => Geometry2d.contains(placement.clip_rect, position)
				None => Bool.False
			}
			var $frame = (description.content!)(description.focused, hovered, placement)

			pointer_down! : PuriHandler.Dispatch(context, PuriHandler.PointerButtonEvent)
			pointer_down! = |context, event| match event.button {
				Some(Primary) => if Geometry2d.contains(placement.clip_rect, event.position) {
					focused_context = (description.request_focus!)(context)
					Handled((description.activate!)(focused_context))
				} else {
					Declined
				}
				_ => Declined
			}
			$frame = Puri.register(PuriHandler.on_pointer_down(pointer_down!), $frame)
			$frame = Puri.register(PuriHandler.focusable(description.focused, placement.rect, description.request_focus!), $frame)

			if description.focused {
				key! : PuriHandler.Dispatch(context, PuriHandler.KeyEvent)
				key! = |context, event| match (event.state, event.key) {
					(KeyDown, Named(Enter)) => Handled((description.activate!)(context))
					(KeyDown, Named(Space)) => Handled((description.activate!)(context))
					_ => Declined
				}
				$frame = Puri.register(PuriHandler.on_key(key!), $frame)
			}

			$frame
		}
	}
}
