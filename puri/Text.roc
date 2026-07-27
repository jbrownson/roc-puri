## Renderer- and layout-independent single-line text. Font selection remains a
## property of the supplied canvas and measurement function.
import geometry.Geometry2d
import Frame
import Canvas
import Geometry
import TextMeasurement

Text := [].{

	Description(paint) : {
		text : Str,
		paint : paint,
	}

	size : TextMeasurement.Metrics -> Geometry.Size
	size = |metrics| Geometry2d.size(metrics.width, metrics.font_ascent + metrics.font_descent)

	widget : Canvas.Operations(result, paint), TextMeasurement.Metrics, Description(paint) -> Frame.Widget(result, state, event)
	widget = |canvas, metrics, description| {
		|placement| {
			baseline = Geometry2d.point(placement.rect.x, placement.rect.y + metrics.font_ascent)
			Frame.from_placement_result((canvas.fill_text!)(baseline, description.paint, description.text))
		}
	}

}
