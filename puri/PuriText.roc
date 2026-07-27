## Renderer- and layout-independent single-line text. Font selection remains a
## property of the supplied canvas and measurement function.
import geometry.Geometry2d
import Puri
import PuriCanvas
import PuriTextMeasurement

PuriText := [].{

	Measure : PuriTextMeasurement.Measure

	Text(paint) : {
		text : Str,
		paint : paint,
	}

	widget : PuriCanvas.Canvas(placed, paint), PuriTextMeasurement.Metrics, Text(paint) -> Puri.Widget(placed, context)
	widget = |canvas, metrics, description| {
		|frame, placement| {
			baseline = Geometry2d.point(placement.rect.x, placement.rect.y + metrics.font_ascent)
			placed = (canvas.fill_text!)(frame.placed, baseline, description.paint, description.text)
			Puri.with_placed(placed, frame)
		}
	}

	text! : PuriCanvas.Canvas(placed, paint), Measure, Text(paint) => Puri.MeasuredWidget(placed, context)
	text! = |canvas, measure!, description| {
		metrics = measure!(description.text)
		size = Geometry2d.size(metrics.width, metrics.font_ascent + metrics.font_descent)
		{
			preferred_size: size,
			minimum_size: size,
			widget!: PuriText.widget(canvas, metrics, description),
		}
	}
}
