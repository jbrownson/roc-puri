## A conventional text button built from PuriButton and PuriText. Behavior,
## appearance, focus, and callbacks are all supplied anew each frame.
import geometry.Geometry2d
import Puri
import PuriButton
import PuriCanvas
import PuriText
import PuriTextMeasurement

PuriTextButton := [].{

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

	TextButton(context, paint) : {
		style : Style(paint),
		text : Str,
		focused : Bool,
		pointer_position : [Some(Geometry2d.Point(F32)), None],
		request_focus! : PuriButton.Action(context),
		activate! : PuriButton.Action(context),
	}

	text_button! : PuriCanvas.Canvas(placed, paint), PuriTextMeasurement.Measure, TextButton(context, paint) => Puri.MeasuredWidget(placed, context)
	text_button! = |canvas, measure!, description| {
		style = description.style
		metrics = measure!(description.text)
		text_size = Geometry2d.size(metrics.width, metrics.font_ascent + metrics.font_descent)
		size = Geometry2d.expand_size(style.padding, text_size)
		text_widget! = PuriText.widget(canvas, metrics, { text: description.text, paint: style.text_paint })
		content! : PuriButton.Content(placed, context)
		content! = |frame, focused, hovered, placement| {
			background = if hovered style.hover_background_paint else style.background_paint
			border = if focused style.focus_border_paint else if hovered style.hover_border_paint else style.border_paint
			border_width = if focused style.focus_border_width else style.border_width
			var $placed = (canvas.fill_rect!)(frame.placed, placement.rect, background)
			$placed = (canvas.stroke_rect!)($placed, placement.rect, border, border_width)
			text_rect = Geometry2d.inset_rect(style.padding, placement.rect)
			text_placement = {
				rect: text_rect,
				clip_rect: Geometry2d.intersect_rect(text_rect, placement.clip_rect),
			}
			text_widget!(Puri.with_placed($placed, frame), text_placement)
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
			widget!: PuriButton.button(button),
		}
	}
}
