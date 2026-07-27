## Chrome-free single-line editable text rendered through Canvas at a settled
## placement. Content padding belongs to the control: it affects sizing,
## drawing, and caret placement while the entire allocated rectangle remains
## interactive. The Description record is ephemeral input for one frame; it
## says nothing about how an application stores its model.
import geometry.Geometry2d
import Frame
import Canvas
import Event
import Geometry
import Handler
import LineEditing
import CaretMap
import TextMeasurement

EditableText := [].{

	Style(paint) : {
		padding : Geometry.Insets,
		text_paint : paint,
		caret_paint : paint,
		caret_width : Geometry.Scalar,
		selection_paint : paint,
	}

	Focus(state) : state, LineEditing.SelectionState => state
	Change(state) : state, Str, LineEditing.SelectionState => state
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
				selection : LineEditing.SelectionState,
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
		Geometry2d.expand_size(style.padding, Geometry2d.size(text_metrics.width, font_height))
	}

	minimum_size : Style(paint), TextMeasurement.Metrics -> Geometry.Size
	minimum_size = |style, line_metrics| {
		font_height = line_metrics.font_ascent + line_metrics.font_descent
		Geometry2d.expand_size(style.padding, Geometry2d.size(0, font_height))
	}

	widget! : Canvas.Operations(result, paint), Measure, TextMeasurement.Metrics, Description(state, paint) => Frame.Widget(result, state, Events(events))
		where [result.default : result, result.plus : result, result -> result]
	widget! = |canvas, measure!, line_metrics, description| {
		style = description.style
		string = description.text
		interaction = description.interaction
		caret_positions = CaretMap.measure!(measure!, string)
		font_height = line_metrics.font_ascent + line_metrics.font_descent
		|placement| {
			content_rect = Geometry2d.inset_rect(style.padding, placement.rect)
			content_clip = Geometry2d.intersect_rect(content_rect, placement.clip_rect)
			hit_rect = Geometry2d.intersect_rect(placement.rect, placement.clip_rect)
			caret_offset = match interaction {
				Focused(data) => {
					selection = LineEditing.clamp_selection(string, data.selection)
					CaretMap.x_at(caret_positions, selection.focus)
				}
				Unfocused(_) => 0
			}
			content_width = F32.max(0, content_rect.width)
			scroll_x = F32.max(0, caret_offset + style.caret_width - content_width)
			text_x = content_rect.x - scroll_x
			text_top = content_rect.y
			baseline = text_top + line_metrics.font_ascent
			clipped_result = (canvas.with_clip!)(
				content_clip,
				|| {
					Result : result
					var $result = Result.default()
					match interaction {
						Focused(data) => {
							range = LineEditing.selection_range(string, data.selection)
							if range.start != range.end {
								selection_x = text_x + CaretMap.x_at(caret_positions, range.start)
								selection_width = CaretMap.x_at(caret_positions, range.end) - CaretMap.x_at(caret_positions, range.start)
								$result = $result + (canvas.fill_rect!)(Geometry2d.rect(selection_x, text_top, selection_width, font_height), style.selection_paint)
							}
						}
						Unfocused(_) => {}
					}

					$result = $result + (canvas.fill_text!)(Geometry2d.point(text_x, baseline), style.text_paint, string)

					match interaction {
						Focused(_) => {
							caret_position_x = text_x + caret_offset
							$result = $result + (canvas.fill_rect!)(Geometry2d.rect(caret_position_x, text_top, style.caret_width, font_height), style.caret_paint)
						}
						Unfocused(_) => {}
					}
					$result
				},
			)
			frame = Frame.from_placement_result(clipped_result)

			handle_pointer_down! : Handler.HandleEvent(state, Event.PointerButtonEvent)
			handle_pointer_down! = |state, pointer| match pointer.button {
				Some(Primary) => if Geometry2d.contains(hit_rect, pointer.position) {
					index = CaretMap.closest_index(caret_positions, pointer.position.x - text_x)
					match interaction {
						Unfocused(focus!) => {
							selection = LineEditing.start_pointer_selection(string, LineEditing.empty_selection, index, pointer.clicks, Bool.False)
							Handled(focus!(state, selection))
						}
						Focused(data) => {
							selection = LineEditing.start_pointer_selection(string, data.selection, index, pointer.clicks, pointer.modifiers.shift)
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
				Focused(data) => if LineEditing.is_dragging(data.selection) {
					index = CaretMap.closest_index(caret_positions, pointer.position.x - text_x)
					Handled((data.change!)(state, string, LineEditing.continue_drag(string, data.selection, index)))
				} else {
					Declined
				}
				Unfocused(_) => Declined
			}

			handle_pointer_up! : Handler.HandleEvent(state, Event.PointerButtonEvent)
			handle_pointer_up! = |state, _pointer| match interaction {
				Focused(data) => if LineEditing.is_dragging(data.selection) {
					Handled((data.change!)(state, string, LineEditing.end_drag(data.selection)))
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
					_ => match LineEditing.handle_key(string, data.selection, key) {
						Updated(next) => Handled((data.change!)(state, next.text, next.selection))
						Copy(selected) => Handled((data.clipboard.write!)(state, selected))
						Cut(cut) => {
							with_clipboard = (data.clipboard.write!)(state, cut.copied)
							Handled((data.change!)(with_clipboard, cut.update.text, cut.update.selection))
						}
						Paste => {
							read = (data.clipboard.read!)(state)
							next = LineEditing.replace_selection(string, read.text, data.selection)
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
