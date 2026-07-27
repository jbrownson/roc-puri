## Roclay-specific visual chrome around a child layout. A Description is an
## ephemeral style description: it adds layout padding, then draws an optional
## background and a border on the settled padded rectangle.
import geometry.Geometry2d
import puri.Frame as PuriFrame
import puri.Canvas
import puri.Geometry as PuriGeometry
import roclay.Roclay

Frame := [].{

	Description(paint) : {
		padding : PuriGeometry.Insets,
		insets : PuriGeometry.Insets,
		background : [Some(paint), None],
		border_paint : paint,
		border_width : PuriGeometry.Scalar,
	}

	framed! : Canvas.Operations(result, paint), Description(paint), Roclay.Layout(PuriFrame(result, state, event)) -> Roclay.Layout(PuriFrame(result, state, event))
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
				PuriFrame.from_placement_result($result)
			},
			padded,
		)
	}
}
