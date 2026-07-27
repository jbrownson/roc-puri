## A conventional text button built from Button and Text. Behavior,
## appearance, focus, and callbacks are all supplied anew each frame.
import geometry.Geometry2d
import Frame
import Button
import Canvas
import Text
import TextMeasurement

TextButton := [].{

	Style(paint) : {
		padding : Geometry2d.Insets(F32),
		background_paint : paint,
		hover_background_paint : paint,
		border_paint : paint,
		hover_border_paint : paint,
		focus_border_paint : paint,
		border_width : F32,
		focus_border_width : F32,
		text_paint : paint,
	}

	Description(state, paint) : {
		style : Style(paint),
		text : Str,
		focused : Bool,
		pointer_position : [Some(Geometry2d.Point(F32)), None],
		request_focus! : Button.Action(state),
		activate! : Button.Action(state),
	}

	text_button! : Canvas.Operations(result, paint), TextMeasurement.Measure, Description(state, paint) => Frame.MeasuredWidget(result, state, Button.Events(events))
		where [result.default : result, result.plus : result, result -> result]
	text_button! = |canvas, measure!, description| {
		style = description.style
		metrics = measure!(description.text)
		text_size = Geometry2d.size(metrics.width, metrics.font_ascent + metrics.font_descent)
		size = Geometry2d.expand_size(style.padding, text_size)
		text_widget! = Text.widget(canvas, metrics, { text: description.text, paint: style.text_paint })
		content! : Button.Content(result, state, Button.Events(events))
		content! = |focused, hovered, placement| {
			background = if hovered style.hover_background_paint else style.background_paint
			border = if focused style.focus_border_paint else if hovered style.hover_border_paint else style.border_paint
			border_width = if focused style.focus_border_width else style.border_width
			background_result = (canvas.fill_rect!)(placement.rect, background)
			border_result = (canvas.stroke_rect!)(placement.rect, border, border_width)
			result = background_result + border_result
			text_rect = Geometry2d.inset_rect(style.padding, placement.rect)
			text_placement = {
				rect: text_rect,
				clip_rect: Geometry2d.intersect_rect(text_rect, placement.clip_rect),
			}
			Frame.from_result(result) + text_widget!(text_placement)
		}
		button = {
			focused: description.focused,
			pointer_position: description.pointer_position,
			request_focus!: description.request_focus!,
			activate!: description.activate!,
			content!,
		}
		{
			preferred_size: size,
			minimum_size: size,
			widget!: Button.button(button),
		}
	}
}
