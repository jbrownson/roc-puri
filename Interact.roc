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
	ClickRunAdjustment(state) : {
		subtract : U8,
		reset! : Action(state),
	}
	Events(events) : [PointerDown(Event.PointerButtonEvent), ..events]

	## Translate the remainder of a multi-click run inside a settled placement
	## into a newly presented frame's reference. A raw single click begins a new
	## run, so reset the adjustment before forwarding it unchanged. Pointer
	## presses outside the placement pass through without changing the run.
	adjust_click_run : [Some(ClickRunAdjustment(state)), None], Frame.Placement, Frame(result, state, Events(events)) -> Frame(result, state, Events(events))
	adjust_click_run = |adjustment, placement, frame| match adjustment {
		None => frame
		Some({ subtract, reset! }) => {
			adjusted_handler = Handler.from_function(
				|state, event| match event {
					PointerDown(pointer) if !(Geometry2d.contains(placement.clip_rect, pointer.position)) => {
						Handler.dispatch!(frame.handler, state, event)
					}
					PointerDown(pointer) if pointer.clicks == 1 => {
						reset_state = reset!(state)
						match Handler.dispatch!(frame.handler, reset_state, event) {
							Handled(next) => Handled(next)
							# Resetting the run is itself a handled transition,
							# even when no enclosed handler wants the click.
							Declined => Handled(reset_state)
						}
					}
					PointerDown(pointer) => {
						clicks = if pointer.clicks > subtract pointer.clicks - subtract else 1
						Handler.dispatch!(frame.handler, state, PointerDown({ ..pointer, clicks }))
					}
					_ => Handler.dispatch!(frame.handler, state, event)
				},
			)
			{ ..frame, handler: adjusted_handler }
		}
	}

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
