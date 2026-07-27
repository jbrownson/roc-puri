## A minimal pure single-line editor description rendered through Canvas
## at a settled placement. The Description record is ephemeral input for one
## frame; it says nothing about how an application stores its model.
import geometry.Geometry2d
import Frame
import Canvas
import Event
import Geometry
import Handler
import LineEdit
import LineEditCarets
import TextMeasurement

LineEditWidget := [].{

	Style(paint) : {
		vertical_padding : Geometry.Scalar,
		horizontal_padding : Geometry.Scalar,
		min_width : Geometry.Scalar,
		text_paint : paint,
		caret_paint : paint,
		selection_paint : paint,
	}

	Focus(state) : state, LineEdit.SelectionState => state
	Change(state) : state, Str, LineEdit.SelectionState => state
	Submit(state) : state => state
	Blur(state) : state => state
	ClipboardReadResult(state) : { state : state, text : Str }
	ClipboardRead(state) : state => ClipboardReadResult(state)
	ClipboardWrite(state) : state, Str => state
	Clipboard(state) : {
		read! : ClipboardRead(state),
		write! : ClipboardWrite(state),
	}

	Interaction(state) := [
		Unfocused(Focus(state)),
		Focused(
			{
				selection : LineEdit.SelectionState,
				change! : Change(state),
				submit! : Submit(state),
				blur! : Blur(state),
				clipboard : Clipboard(state),
			},
		),
	]

	Description(state, paint) : {
		style : Style(paint),
		text : Str,
		interaction : Interaction(state),
	}

	Measure : TextMeasurement.Measure
	Events(events) : [PointerDown(Event.PointerButtonEvent), PointerMove(Event.PointerUpdate), PointerUp(Event.PointerButtonEvent), Key(Event.KeyEvent), ..events]

	preferred_size : Style(paint), TextMeasurement.Metrics, TextMeasurement.Metrics -> Geometry.Size
	preferred_size = |style, text_metrics, line_metrics| {
		font_height = line_metrics.font_ascent + line_metrics.font_descent
		Geometry2d.size(
			F32.max(style.min_width, text_metrics.width + style.horizontal_padding * 2),
			font_height + style.vertical_padding * 2,
		)
	}

	minimum_size : Style(paint), TextMeasurement.Metrics -> Geometry.Size
	minimum_size = |style, line_metrics| {
		font_height = line_metrics.font_ascent + line_metrics.font_descent
		Geometry2d.size(style.min_width, font_height + style.vertical_padding * 2)
	}

	widget! : Canvas.Operations(result, paint), Measure, TextMeasurement.Metrics, Description(state, paint) => Frame.Widget(result, state, Events(events))
		where [result.default : result, result.plus : result, result -> result]
	widget! = |canvas, measure!, line_metrics, edit| {
		style = edit.style
		string = edit.text
		interaction = edit.interaction
		caret_positions = LineEditCarets.measure!(measure!, string)
		font_height = line_metrics.font_ascent + line_metrics.font_descent
		|placement| {
			caret_width = 1.5
			caret_offset = match interaction {
				Focused(data) => {
					selection = LineEdit.clamp_selection(string, data.selection)
					LineEditCarets.x_at(caret_positions, selection.focus)
				}
				Unfocused(_) => 0
			}
			content_width = F32.max(0, placement.rect.width - style.horizontal_padding * 2)
			scroll_x = F32.max(0, caret_offset + caret_width - content_width)
			text_x = placement.rect.x + style.horizontal_padding - scroll_x
			text_top = placement.rect.y + style.vertical_padding
			baseline = text_top + line_metrics.font_ascent
			clipped_result = (canvas.with_clip!)(
				placement.clip_rect,
				|| {
					Result : result
					var $result = Result.default()
					match interaction {
						Focused(data) => {
							range = LineEdit.selection_range(string, data.selection)
							if range.start != range.end {
								selection_x = text_x + LineEditCarets.x_at(caret_positions, range.start)
								selection_width = LineEditCarets.x_at(caret_positions, range.end) - LineEditCarets.x_at(caret_positions, range.start)
								$result = $result + (canvas.fill_rect!)(Geometry2d.rect(selection_x, text_top, selection_width, font_height), style.selection_paint)
							}
						}
						Unfocused(_) => {}
					}

					$result = $result + (canvas.fill_text!)(Geometry2d.point(text_x, baseline), style.text_paint, string)

					match interaction {
						Focused(_) => {
							caret_position_x = text_x + caret_offset
							$result = $result + (canvas.fill_rect!)(Geometry2d.rect(caret_position_x, text_top, caret_width, font_height), style.caret_paint)
						}
						Unfocused(_) => {}
					}
					$result
				},
			)
			frame = Frame.from_placement_result(clipped_result)

			handle_pointer_down! : Handler.HandleEvent(state, Event.PointerButtonEvent)
			handle_pointer_down! = |state, pointer| match pointer.button {
				Some(Primary) => if Geometry2d.contains(placement.clip_rect, pointer.position) {
					index = LineEditCarets.closest_index(caret_positions, pointer.position.x - text_x)
					match interaction {
						Unfocused(focus!) => {
							selection = LineEdit.start_pointer_selection(string, LineEdit.empty_selection, index, pointer.clicks, Bool.False)
							Handled(focus!(state, selection))
						}
						Focused(data) => {
							selection = LineEdit.start_pointer_selection(string, data.selection, index, pointer.clicks, pointer.modifiers.shift)
							Handled((data.change!)(state, string, selection))
						}
					}
				} else {
					Declined
				}
				_ => Declined
			}

			handle_pointer_move! : Handler.HandleEvent(state, Event.PointerUpdate)
			handle_pointer_move! = |state, pointer| match interaction {
				Focused(data) => if LineEdit.is_dragging(data.selection) {
					index = LineEditCarets.closest_index(caret_positions, pointer.position.x - text_x)
					Handled((data.change!)(state, string, LineEdit.continue_drag(string, data.selection, index)))
				} else {
					Declined
				}
				Unfocused(_) => Declined
			}

			handle_pointer_up! : Handler.HandleEvent(state, Event.PointerButtonEvent)
			handle_pointer_up! = |state, _pointer| match interaction {
				Focused(data) => if LineEdit.is_dragging(data.selection) {
					Handled((data.change!)(state, string, LineEdit.end_drag(data.selection)))
				} else {
					Declined
				}
				Unfocused(_) => Declined
			}

			handle_key! : Handler.HandleEvent(state, Event.KeyEvent)
			handle_key! = |state, key| match interaction {
				Focused(data) => match (key.state, key.key) {
					(KeyDown, Named(Enter)) => Handled((data.submit!)(state))
					(KeyDown, Named(Escape)) => Handled((data.blur!)(state))
					_ => match LineEdit.handle_key(string, data.selection, key) {
						Edited(next) => Handled((data.change!)(state, next.text, next.selection))
						Copy(selected) => Handled((data.clipboard.write!)(state, selected))
						Cut(cut) => {
							with_clipboard = (data.clipboard.write!)(state, cut.copied)
							Handled((data.change!)(with_clipboard, cut.edit.text, cut.edit.selection))
						}
						Paste => {
							read = (data.clipboard.read!)(state)
							next = LineEdit.replace_selection(string, read.text, data.selection)
							Handled((data.change!)(read.state, next.text, next.selection))
						}
						Ignored => Declined
					}
				}
				Unfocused(_) => Declined
			}

			handle_event! : Handler.HandleEvent(state, Events(events))
			handle_event! = |state, event| match event {
				PointerDown(pointer) => handle_pointer_down!(state, pointer)
				PointerMove(pointer) => handle_pointer_move!(state, pointer)
				PointerUp(pointer) => handle_pointer_up!(state, pointer)
				Key(key) => handle_key!(state, key)
				_ => Declined
			}
			Frame.register(Handler.from_function(handle_event!), frame)
		}
	}
}
