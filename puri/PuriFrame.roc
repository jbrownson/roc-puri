## Pure visual chrome around a child layout. A Frame is an ephemeral style
## description: it adds layout padding, then draws an optional background and
## a border on the settled padded rectangle.
import roclay.Geometry2d
import Puri
import PuriCanvas
import roclay.Roclay

PuriFrame := [].{

	Frame(paint) : {
		padding : Geometry2d.Insets(F32),
		insets : Geometry2d.Insets(F32),
		background : [Some(paint), None],
		border_paint : paint,
		border_width : F32,
	}

	framed! : PuriCanvas.Canvas(render, paint), Frame(paint), Roclay.Layout(Puri.Frame(render, context)) -> Roclay.Layout(Puri.Frame(render, context))
	framed! = |canvas, style, child| {
		padded = Roclay.padding(style.padding, child)
		Roclay.decorate(
			|frame, placement| {
				frame_rect = Geometry2d.inset_rect(style.insets, placement.rect)
				with_background = match style.background {
					Some(paint) => PuriCanvas.fill_rect!(canvas, frame.render, frame_rect, paint)
					None => frame.render
				}
				with_border = PuriCanvas.stroke_rect!(canvas, with_background, frame_rect, style.border_paint, style.border_width)
				Puri.with_render(with_border, frame)
			},
			padded,
		)
	}
}
