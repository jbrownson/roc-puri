## A conventional line edit composed from Puri's chrome-free EditableText leaf,
## hit-aware layout padding, and independent visual decoration.
import puri.Canvas
import puri.EditableText
import puri.Frame as PuriFrame
import puri.Geometry
import puri.TextMeasurement
import roclay.Roclay
import Frame
import Layout
import Widgets

LineEdit := [].{

	Description(state, paint) : {
		padding : Geometry.Insets,
		decoration : Frame.Decoration(paint),
		editable_text : EditableText.Description(state, paint),
	}

	compose! : Canvas.Operations(result, paint), TextMeasurement.Measure, Description(state, paint) => Roclay.Layout(PuriFrame(result, state, EditableText.Events(events)))
		where [result.default : result, result.plus : result, result -> result]
	compose! = |canvas, measure!, description| {
		editable_text = Widgets.editable_text!(canvas, measure!, description.editable_text)
		padded = Layout.hit_padding(description.padding, editable_text)
		Frame.decorate!(canvas, description.decoration, padded)
	}
}
