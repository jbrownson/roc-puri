## A Puri frame: a canvas-interpreter result and the transient Handler
## assembled while a layout engine places widgets.
import geometry.Geometry2d
import Handler

Frame(placement_result, state, event) := {
	placement_result : placement_result,
	handler : Handler(state, event),
}.{
	Placement : Geometry2d.Placement(F32)
	Size : Geometry2d.Size(F32)

	Widget(placement_result, state, event) : Placement => Frame(placement_result, state, event)

	MeasuredWidget(placement_result, state, event) : {
		preferred_size : Size,
		minimum_size : Size,
		widget! : Widget(placement_result, state, event),
	}

	default : () -> Frame(placement_result, state, event)
		where [placement_result.default : placement_result]
	default = || {
		PlacementResult : placement_result
		{ placement_result: PlacementResult.default(), handler: Handler.default() }
	}

	plus : Frame(placement_result, state, event), Frame(placement_result, state, event) -> Frame(placement_result, state, event)
		where [placement_result.plus : placement_result, placement_result -> placement_result]
	plus = |earlier, later| {
		placement_result: earlier.placement_result + later.placement_result,
		handler: earlier.handler + later.handler,
	}

	from_placement_result : placement_result -> Frame(placement_result, state, event)
	from_placement_result = |placement_result| { placement_result, handler: Handler.default() }

	register : Handler(state, event), Frame(placement_result, state, event) -> Frame(placement_result, state, event)
	register = |handler, frame| {
		..frame,
		handler: frame.handler + handler,
	}
}
