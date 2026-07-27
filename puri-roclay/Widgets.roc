## Roclay leaf adapters for Puri's placement-only standard widgets.
import puri.Button
import puri.Canvas
import puri.Checkbox as PuriCheckbox
import puri.Frame as PuriFrame
import puri.LineEditWidget as PuriLineEdit
import puri.Text as PuriText
import puri.TextButton as PuriTextButton
import puri.TextMeasurement
import roclay.Roclay
import Layout

Widgets := [].{
	text! : Canvas.Operations(result, paint), TextMeasurement.Measure, PuriText.Description(paint) => Roclay.Layout(PuriFrame(result, state, event))
	text! = |canvas, measure!, description| {
		metrics = measure!(description.text)
		size = PuriText.size(metrics)
		Layout.leaf(size, size, PuriText.widget(canvas, metrics, description))
	}

	text_button! : Canvas.Operations(result, paint), TextMeasurement.Measure, PuriTextButton.Description(state, paint) => Roclay.Layout(PuriFrame(result, state, Button.Events(events)))
		where [result.default : result, result.plus : result, result -> result]
	text_button! = |canvas, measure!, description| {
		metrics = measure!(description.text)
		size = PuriTextButton.size(description.style, metrics)
		Layout.leaf(size, size, PuriTextButton.widget(canvas, metrics, description))
	}

	checkbox! : Canvas.Operations(result, paint), TextMeasurement.Measure, PuriCheckbox.Description(state, paint) => Roclay.Layout(PuriFrame(result, state, Button.Events(events)))
		where [result.default : result, result.plus : result, result -> result]
	checkbox! = |canvas, measure!, description| {
		metrics = measure!(description.label)
		preferred_size = PuriCheckbox.preferred_size(description.style, metrics)
		minimum_size = PuriCheckbox.minimum_size(description.style, metrics)
		widget! = PuriCheckbox.widget(canvas, measure!, metrics, description)
		Layout.leaf(preferred_size, minimum_size, widget!)
	}

	line_edit! : Canvas.Operations(result, paint), TextMeasurement.Measure, PuriLineEdit.Description(state, paint) => Roclay.Layout(PuriFrame(result, state, PuriLineEdit.Events(events)))
		where [result.default : result, result.plus : result, result -> result]
	line_edit! = |canvas, measure!, description| {
		text_metrics = measure!(description.text)
		line_metrics = measure!("Mg")
		preferred_size = PuriLineEdit.preferred_size(description.style, text_metrics, line_metrics)
		minimum_size = PuriLineEdit.minimum_size(description.style, line_metrics)
		widget! = PuriLineEdit.widget!(canvas, measure!, line_metrics, description)
		Layout.leaf(preferred_size, minimum_size, widget!)
	}
}
