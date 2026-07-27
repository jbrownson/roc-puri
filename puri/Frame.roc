## A Puri frame: a canvas-interpreter result and the transient Handler
## assembled while a layout engine places widgets.
import geometry.Geometry2d
import Handler

Frame(result, state, event) := {
	result : result,
	handler : Handler(state, event),
}.{
	Placement : Geometry2d.Placement(F32)
	Size : Geometry2d.Size(F32)

	Widget(result, state, event) : Placement => Frame(result, state, event)

	MeasuredWidget(result, state, event) : {
		preferred_size : Size,
		minimum_size : Size,
		widget! : Widget(result, state, event),
	}

	default : () -> Frame(result, state, event)
		where [result.default : result]
	default = || {
		Result : result
		{ result: Result.default(), handler: Handler.default() }
	}

	plus : Frame(result, state, event), Frame(result, state, event) -> Frame(result, state, event)
		where [result.plus : result, result -> result]
	plus = |earlier, later| {
		result: earlier.result + later.result,
		handler: earlier.handler + later.handler,
	}

	from_result : result -> Frame(result, state, event)
	from_result = |result| { result, handler: Handler.default() }

	register : Handler(state, event), Frame(result, state, event) -> Frame(result, state, event)
	register = |handler, frame| {
		..frame,
		handler: frame.handler + handler,
	}
}
