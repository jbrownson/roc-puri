## Puri's per-frame value: a canvas-interpreter result and the transient
## Handler assembled while a layout engine places widgets.
import geometry.Geometry2d
import PuriHandler

Puri := [].{

	Placement : Geometry2d.Placement(F32)
	Size : Geometry2d.Size(F32)

	Frame(result, state, event) := {
		result : result,
		handler : PuriHandler.Handler(state, event),
	}.{
		default : () -> Frame(result, state, event)
			where [result.default : result]
		default = || {
			Result : result
			{ result: Result.default(), handler: PuriHandler.Handler.default() }
		}

		plus : Frame(result, state, event), Frame(result, state, event) -> Frame(result, state, event)
			where [result.plus : result, result -> result]
		plus = |earlier, later| {
			result: earlier.result + later.result,
			handler: earlier.handler + later.handler,
		}
	}

	Widget(result, state, event) : Placement => Frame(result, state, event)

	MeasuredWidget(result, state, event) : {
		preferred_size : Size,
		minimum_size : Size,
		widget! : Widget(result, state, event),
	}

	frame : result -> Frame(result, state, event)
	frame = |result| { result, handler: PuriHandler.Handler.default() }

	register : PuriHandler.Handler(state, event), Frame(result, state, event) -> Frame(result, state, event)
	register = |handler, frame_value| {
		..frame_value,
		handler: frame_value.handler + handler,
	}
}
