## Roclay-specific visual chrome around a child layout. A Frame is an
## ephemeral style description: it adds layout padding, then draws an optional
## background and a border on the settled padded rectangle.
import geometry.Geometry2d
import puri.Puri
import puri.PuriCanvas
import roclay.Roclay

PuriFrame := [].{

	Frame(paint) : {
		padding : Geometry2d.Insets(F32),
		insets : Geometry2d.Insets(F32),
		background : [Some(paint), None],
		border_paint : paint,
		border_width : F32,
	}

	framed! : PuriCanvas.Canvas(placed, paint), Frame(paint), Roclay.Layout(Puri.Frame(placed, context)) -> Roclay.Layout(Puri.Frame(placed, context))
	framed! = |canvas, style, child| {
		padded = Roclay.padding(style.padding, child)
		Roclay.decorate(
			|frame, placement| {
				frame_rect = Geometry2d.inset_rect(style.insets, placement.rect)
				with_background = match style.background {
					Some(paint) => (canvas.fill_rect!)(frame.placed, frame_rect, paint)
					None => frame.placed
				}
				with_border = (canvas.stroke_rect!)(with_background, frame_rect, style.border_paint, style.border_width)
				Puri.with_placed(with_border, frame)
			},
			padded,
		)
	}
}
