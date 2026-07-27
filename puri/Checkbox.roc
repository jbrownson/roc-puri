## A small checkbox specialization built from Button. Its label, checked
## state, focus, callbacks, and style are all supplied anew each frame.
import geometry.Geometry2d
import Frame
import Button
import Canvas
import TextMeasurement

Checkbox := [].{

	Style(paint) : {
		box_size : F32,
		gap : F32,
		vertical_padding : F32,
		horizontal_padding : F32,
		border_width : F32,
		mark_width : F32,
		box_paint : paint,
		hover_box_paint : paint,
		border_paint : paint,
		hover_border_paint : paint,
		mark_paint : paint,
		text_paint : paint,
		focus_paint : paint,
	}

	Description(state, paint) : {
		style : Style(paint),
		label : Str,
		checked : Bool,
		focused : Bool,
		pointer_position : [Some(Geometry2d.Point(F32)), None],
		request_focus! : Button.Action(state),
		toggle! : Button.Action(state),
	}

	Measure : TextMeasurement.Measure

	is_continuation_byte : U8 -> Bool
	is_continuation_byte = |byte| byte >= 128 and byte < 192

	fit_label! : Measure, Str, F32 => Str
	fit_label! = |measure!, string, available_width| {
		if (measure!(string)).width <= available_width {
			string
		} else {
			suffix = "..."
			suffix_width = (measure!(suffix)).width
			if suffix_width > available_width {
				""
			} else {
				bytes = Str.to_utf8(string)
				var $prefix_bytes = []
				var $best = ""
				var $index = 0
				for byte in bytes {
					$prefix_bytes = List.append($prefix_bytes, byte)
					next_index = $index + 1
					complete = if next_index >= List.len(bytes) {
						Bool.True
					} else match List.get(bytes, next_index) {
						Ok(next) => !(Checkbox.is_continuation_byte(next))
						Err(_) => Bool.True
					}
					if complete {
						match Str.from_utf8($prefix_bytes) {
							Ok(prefix) => if (measure!(prefix)).width + suffix_width <= available_width {
								$best = prefix
							}
							Err(_) => {}
						}
					}
					$index = next_index
				}
				Str.concat($best, suffix)
			}
		}
	}

	checkbox! : Canvas.Operations(result, paint), Measure, Description(state, paint) => Frame.MeasuredWidget(result, state, Button.Events(events))
		where [result.default : result, result.plus : result, result -> result]
	checkbox! = |canvas, measure!, checkbox| {
		style = checkbox.style
		metrics = measure!(checkbox.label)
		font_height = metrics.font_ascent + metrics.font_descent
		content_height = F32.max(style.box_size, font_height)
		preferred_size = Geometry2d.size(
			style.horizontal_padding * 2 + style.box_size + style.gap + metrics.width,
			style.vertical_padding * 2 + content_height,
		)
		minimum_size = Geometry2d.size(
			style.horizontal_padding * 2 + style.box_size + style.gap,
			preferred_size.height,
		)
		content! : Button.Content(result, state, Button.Events(events))
		content! = |focused, hovered, placement| {
			content_top = placement.rect.y + style.vertical_padding
			box_x = placement.rect.x + style.horizontal_padding
			box_y = content_top + (content_height - style.box_size) / 2
			box_rect = Geometry2d.rect(box_x, box_y, style.box_size, style.box_size)
			box_paint = if hovered style.hover_box_paint else style.box_paint
			border_paint = if hovered style.hover_border_paint else style.border_paint
			var $result =
				(canvas.fill_rect!)(box_rect, box_paint) +
					(canvas.stroke_rect!)(box_rect, border_paint, style.border_width)

			if checkbox.checked {
				left = Geometry2d.point(box_x + style.box_size * 0.22, box_y + style.box_size * 0.54)
				middle = Geometry2d.point(box_x + style.box_size * 0.43, box_y + style.box_size * 0.75)
				right = Geometry2d.point(box_x + style.box_size * 0.80, box_y + style.box_size * 0.29)
				$result = $result + (canvas.stroke_line!)(left, middle, style.mark_paint, style.mark_width)
				$result = $result + (canvas.stroke_line!)(middle, right, style.mark_paint, style.mark_width)
			}

			text_x = box_x + style.box_size + style.gap
			available_text_width = F32.max(0, placement.rect.x + placement.rect.width - style.horizontal_padding - text_x)
			label = Checkbox.fit_label!(measure!, checkbox.label, available_text_width)
			baseline = content_top + (content_height - font_height) / 2 + metrics.font_ascent
			$result = $result + (canvas.fill_text!)(Geometry2d.point(text_x, baseline), style.text_paint, label)

			if focused {
				$result = $result + (canvas.stroke_rect!)(placement.rect, style.focus_paint, 2)
			}
			Frame.from_result($result)
		}
		button = {
			focused: checkbox.focused,
			pointer_position: checkbox.pointer_position,
			request_focus!: checkbox.request_focus!,
			activate!: checkbox.toggle!,
			content!,
		}
		{
			preferred_size,
			minimum_size,
			widget!: Button.button(button),
		}
	}
}
