## Roclay-specific visual chrome around a child layout. Decoration draws on the
## settled rectangle; Description conventionally composes it with layout
## padding.
import geometry.Geometry2d
import puri.Frame as PuriFrame
import puri.Canvas
import puri.Geometry as PuriGeometry
import roclay.Roclay

Frame := [].{

	Decoration(paint) : {
		insets : PuriGeometry.Insets,
		background : [Some(paint), None],
		border_paint : paint,
		border_width : PuriGeometry.Scalar,
	}

	Description(paint) : {
		padding : PuriGeometry.Insets,
		decoration : Decoration(paint),
	}

	decorate! : Canvas.Operations(result, paint), Decoration(paint), Roclay.Layout(PuriFrame(result, state, event)) -> Roclay.Layout(PuriFrame(result, state, event))
		where [result.default : result, result.plus : result, result -> result]
	decorate! = |canvas, decoration, child| {
		Roclay.around(
			|placement, place_inner!| {
				frame_rect = Geometry2d.inset_rect(decoration.insets, placement.rect)
				Result : result
				var $background = Result.default()
				match decoration.background {
					Some(paint) => {
						$background = $background + (canvas.fill_rect!)(frame_rect, paint)
					}
					None => {}
				}
				background_frame = PuriFrame.from_placement_result($background)
				child_frame = place_inner!()
				border_result = (canvas.stroke_rect!)(frame_rect, decoration.border_paint, decoration.border_width)
				border_frame = PuriFrame.from_placement_result(border_result)
				background_frame + child_frame + border_frame
			},
			child,
		)
	}

	framed! : Canvas.Operations(result, paint), Description(paint), Roclay.Layout(PuriFrame(result, state, event)) -> Roclay.Layout(PuriFrame(result, state, event))
		where [result.default : result, result.plus : result, result -> result]
	framed! = |canvas, description, child| {
		padded = Roclay.padding(description.padding, child)
		Frame.decorate!(canvas, description.decoration, padded)
	}
}
