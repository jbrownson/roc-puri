## Renderer- and layout-independent single-line text. Font selection remains a
## property of the supplied canvas and measurement function.
import geometry.Geometry2d
import Frame
import Canvas
import TextMeasurement

Text := [].{

	Measure : TextMeasurement.Measure

	Description(paint) : {
		text : Str,
		paint : paint,
	}

	widget : Canvas.Operations(result, paint), TextMeasurement.Metrics, Description(paint) -> Frame.Widget(result, state, event)
	widget = |canvas, metrics, description| {
		|placement| {
			baseline = Geometry2d.point(placement.rect.x, placement.rect.y + metrics.font_ascent)
			Frame.from_placement_result((canvas.fill_text!)(baseline, description.paint, description.text))
		}
	}

	text! : Canvas.Operations(result, paint), Measure, Description(paint) => Frame.MeasuredWidget(result, state, event)
	text! = |canvas, measure!, description| {
		metrics = measure!(description.text)
		size = Geometry2d.size(metrics.width, metrics.font_ascent + metrics.font_descent)
		{
			preferred_size: size,
			minimum_size: size,
			widget!: Text.widget(canvas, metrics, description),
		}
	}
}
