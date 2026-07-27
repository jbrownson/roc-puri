## Puri's per-frame state: placement effects threaded through direct canvas
## calls and a transient Handler assembled by any layout engine.
import geometry.Geometry2d
import PuriHandler

Puri := [].{

	Placement : Geometry2d.Placement(F32)
	Size : Geometry2d.Size(F32)

	Frame(placed, context) : {
		placed : placed,
		handler : PuriHandler.Handler(context),
	}

	Widget(placed, context) : Frame(placed, context), Placement => Frame(placed, context)

	MeasuredWidget(placed, context) : {
		preferred_size : Size,
		minimum_size : Size,
		widget! : Widget(placed, context),
	}

	Update(value) : value => value

	CaptureResult(placed, context) : {
		frame : Frame(placed, context),
		captured : PuriHandler.Handler(context),
	}

	frame : placed -> Frame(placed, context)
	frame = |placed| { placed, handler: PuriHandler.empty }

	with_placed : placed, Frame(placed, context) -> Frame(placed, context)
	with_placed = |placed, frame_value| { ..frame_value, placed }

	register : PuriHandler.Handler(context), Frame(placed, context) -> Frame(placed, context)
	register = |handler, frame_value| {
		..frame_value,
		handler: PuriHandler.combine(frame_value.handler, handler),
	}

	## Capture a subtree's registrations while preserving its placement effects. A
	## controlled layout container can wrap, transform, or discard `captured`
	## before composing it back into `frame.handler`.
	capture! : Frame(placed, context), Update(Frame(placed, context)) => CaptureResult(placed, context)
	capture! = |frame_value, place!| {
		outer = frame_value.handler
		placed = place!({ ..frame_value, handler: PuriHandler.empty })
		{
			frame: { ..placed, handler: outer },
			captured: placed.handler,
		}
	}
}
