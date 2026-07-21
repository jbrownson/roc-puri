## Puri's per-frame state: a renderer threaded through direct draw calls and a
## transient Handler assembled during Roclay placement.
import Geometry2d
import PuriHandler

Puri := [].{

	Placement : Geometry2d.Placement(F32)

	Frame(render, context) : {
		render : render,
		handler : PuriHandler.Handler(context),
	}

	Widget(render, context) : Frame(render, context), Placement => Frame(render, context)
	Update(value) : value => value

	CaptureResult(render, context) : {
		frame : Frame(render, context),
		captured : PuriHandler.Handler(context),
	}

	frame : render -> Frame(render, context)
	frame = |render| { render, handler: PuriHandler.empty }

	with_render : render, Frame(render, context) -> Frame(render, context)
	with_render = |render, frame_value| { ..frame_value, render }

	register : PuriHandler.Handler(context), Frame(render, context) -> Frame(render, context)
	register = |handler, frame_value| {
		..frame_value,
		handler: PuriHandler.combine(frame_value.handler, handler),
	}

	## Capture a subtree's registrations while preserving its rendering. A
	## controlled Roclay container can wrap, transform, or discard `captured`
	## before composing it back into `frame.handler`.
	capture! : Frame(render, context), Update(Frame(render, context)) => CaptureResult(render, context)
	capture! = |frame_value, place!| {
		outer = frame_value.handler
		placed = place!({ ..frame_value, handler: PuriHandler.empty })
		{
			frame: { ..placed, handler: outer },
			captured: placed.handler,
		}
	}
}
