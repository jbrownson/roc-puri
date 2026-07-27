## Puri's per-frame value: an accumulated canvas-interpreter result and the
## transient Handler assembled while a layout engine places widgets.
import geometry.Geometry2d
import PuriHandler

Puri := [].{

	Placement : Geometry2d.Placement(F32)
	Size : Geometry2d.Size(F32)

	Frame(result, context) : {
		result : result,
		handler : PuriHandler.Handler(context),
	}

	Widget(result, context) : Frame(result, context), Placement => Frame(result, context)

	MeasuredWidget(result, context) : {
		preferred_size : Size,
		minimum_size : Size,
		widget! : Widget(result, context),
	}

	Update(value) : value => value

	CaptureResult(result, context) : {
		frame : Frame(result, context),
		captured : PuriHandler.Handler(context),
	}

	frame : result -> Frame(result, context)
	frame = |result| { result, handler: PuriHandler.empty }

	with_result : result, Frame(result, context) -> Frame(result, context)
	with_result = |result, frame_value| { ..frame_value, result }

	register : PuriHandler.Handler(context), Frame(result, context) -> Frame(result, context)
	register = |handler, frame_value| {
		..frame_value,
		handler: PuriHandler.combine(frame_value.handler, handler),
	}

	## Capture a subtree's registrations while preserving its render result. A
	## controlled layout container can wrap, transform, or discard `captured`
	## before composing it back into `frame.handler`.
	capture! : Frame(result, context), Update(Frame(result, context)) => CaptureResult(result, context)
	capture! = |frame_value, place!| {
		outer = frame_value.handler
		inner_frame = place!({ ..frame_value, handler: PuriHandler.empty })
		{
			frame: { ..inner_frame, handler: outer },
			captured: inner_frame.handler,
		}
	}
}
