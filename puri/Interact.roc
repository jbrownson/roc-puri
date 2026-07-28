## Interaction combinators over settled placements.
import geometry.Geometry2d
import Frame
import Event
import Handler

Interact := [].{

	Action(state) : state => state
	ClickFilter : U8 -> Bool
	PointerFilter : Event.PointerButtonEvent -> Bool
	PlacedPointerFilter : Geometry2d.Placement(F32), Event.PointerButtonEvent -> Bool
	PointerAction(state) : state, Event.PointerButtonEvent => state
	PlacedPointerAction(state) : state, Geometry2d.Placement(F32), Event.PointerButtonEvent => state
	Events(events) : [PointerDown(Event.PointerButtonEvent), ..events]

	on_primary_pointer_down_where : PlacedPointerFilter, PlacedPointerAction(state) -> Frame.Widget(result, state, Events(events))
		where [result.default : result]
	on_primary_pointer_down_where = |accepts, action!| {
		|placement| {
			handle_event! : Handler.HandleEvent(state, Events(events))
			handle_event! = |state, event| match event {
				PointerDown(pointer) => match pointer.button {
					Some(Primary) if accepts(placement, pointer) and Geometry2d.contains(placement.clip_rect, pointer.position) => {
						Handled(action!(state, placement, pointer))
					}
					_ => Declined
				}
				_ => Declined
			}
			Frame.register(Handler.from_function(handle_event!), Frame.default())
		}
	}

	on_primary_pointer_down : PointerFilter, PointerAction(state) -> Frame.Widget(result, state, Events(events))
		where [result.default : result]
	on_primary_pointer_down = |accepts, action!| {
		Interact.on_primary_pointer_down_where(
			|_placement, pointer| accepts(pointer),
			|state, _placement, pointer| action!(state, pointer),
		)
	}

	on_primary_click : ClickFilter, Action(state) -> Frame.Widget(result, state, Events(events))
		where [result.default : result]
	on_primary_click = |accepts, action!| {
		Interact.on_primary_pointer_down(
			|pointer| accepts(pointer.clicks),
			|state, _pointer| action!(state),
		)
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
