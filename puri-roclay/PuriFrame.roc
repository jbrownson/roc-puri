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

	framed! : PuriCanvas.Canvas(result, paint), Frame(paint), Roclay.Layout(Puri.Frame(result, context)) -> Roclay.Layout(Puri.Frame(result, context))
		where [result.default : result, result.plus : result, result -> result]
	framed! = |canvas, style, child| {
		padded = Roclay.padding(style.padding, child)
		Roclay.decorate(
			|placement| {
				frame_rect = Geometry2d.inset_rect(style.insets, placement.rect)
				Result : result
				var $result = Result.default()
				match style.background {
					Some(paint) => {
						$result = $result + (canvas.fill_rect!)(frame_rect, paint)
					}
					None => {}
				}
				$result = $result + (canvas.stroke_rect!)(frame_rect, style.border_paint, style.border_width)
				Puri.frame($result)
			},
			padded,
		)
	}
}
