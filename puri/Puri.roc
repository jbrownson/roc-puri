## Puri's per-frame value: a canvas-interpreter result and the transient
## Handler assembled while a layout engine places widgets.
import geometry.Geometry2d
import PuriHandler

Puri := [].{

	Placement : Geometry2d.Placement(F32)
	Size : Geometry2d.Size(F32)

	Frame(result, context) := {
		result : result,
		handler : PuriHandler.Handler(context),
	}.{
		default : () -> Frame(result, context)
			where [result.default : result]
		default = || {
			Result : result
			{ result: Result.default(), handler: PuriHandler.Handler.default() }
		}

		plus : Frame(result, context), Frame(result, context) -> Frame(result, context)
			where [result.plus : result, result -> result]
		plus = |earlier, later| {
			result: earlier.result + later.result,
			handler: earlier.handler + later.handler,
		}
	}

	Widget(result, context) : Placement => Frame(result, context)

	MeasuredWidget(result, context) : {
		preferred_size : Size,
		minimum_size : Size,
		widget! : Widget(result, context),
	}

	frame : result -> Frame(result, context)
	frame = |result| { result, handler: PuriHandler.Handler.default() }

	register : PuriHandler.Handler(context), Frame(result, context) -> Frame(result, context)
	register = |handler, frame_value| {
		..frame_value,
		handler: frame_value.handler + handler,
	}
}
