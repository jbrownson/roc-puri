## A minimal pure single-line editor description rendered through Canvas
## at a settled placement. The Description record is ephemeral input for one
## frame; it says nothing about how an application stores its model.
import geometry.Geometry2d
import Frame
import Canvas
import Event
import Handler
import LineEdit
import TextMeasurement

LineEditWidget := [].{

	Style(paint) : {
		vertical_padding : F32,
		horizontal_padding : F32,
		min_width : F32,
		text_paint : paint,
		caret_paint : paint,
		selection_paint : paint,
	}

	Focus(state) : state, LineEdit.LineEditSelection => state
	Change(state) : state, Str, LineEdit.LineEditSelection => state
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
				selection : LineEdit.LineEditSelection,
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

	CaretPosition : {
		index : U64,
		x : F32,
	}

	measure_carets_from! : Measure, Str, U64, List(CaretPosition) => List(CaretPosition)
	measure_carets_from! = |measure!, string, index, positions| {
		metrics = measure!(LineEdit.prefix(string, index))
		next_positions = List.append(positions, { index, x: metrics.width })
		bytes = Str.to_utf8(string)
		if index >= List.len(bytes) {
			next_positions
		} else {
			next = LineEdit.next_boundary(bytes, index)
			LineEditWidget.measure_carets_from!(measure!, string, next, next_positions)
		}
	}

	measure_carets! : Measure, Str => List(CaretPosition)
	measure_carets! = |measure!, string| LineEditWidget.measure_carets_from!(measure!, string, 0, [])

	closest_caret : List(CaretPosition), F32 -> U64
	closest_caret = |positions, target| {
		var $best_index = 0
		var $best_distance = 3.4028234663852886e38
		for position in positions {
			distance = F32.abs(position.x - target)
			if distance < $best_distance {
				$best_distance = distance
				$best_index = position.index
			}
		}
		$best_index
	}

	caret_x : List(CaretPosition), U64 -> F32
	caret_x = |positions, requested| {
		var $x = 0
		for position in positions {
			if position.index == requested {
				$x = position.x
			}
		}
		$x
	}

	line_edit! : Canvas.Operations(result, paint), Measure, Description(state, paint) => Frame.MeasuredWidget(result, state, Events(events))
		where [result.default : result, result.plus : result, result -> result]
	line_edit! = |canvas, measure!, edit| {
		style = edit.style
		string = edit.text
		interaction = edit.interaction
		text_metrics = measure!(string)
		line_metrics = measure!("Mg")
		caret_positions = LineEditWidget.measure_carets!(measure!, string)
		font_height = line_metrics.font_ascent + line_metrics.font_descent
		preferred_size = Geometry2d.size(
			F32.max(style.min_width, text_metrics.width + style.horizontal_padding * 2),
			font_height + style.vertical_padding * 2,
		)
		minimum_size = Geometry2d.size(style.min_width, preferred_size.height)
		{
			preferred_size,
			minimum_size,
			widget!: |placement| {
				caret_width = 1.5
				caret_offset = match interaction {
					Focused(data) => {
						selection = LineEdit.clamp_selection(string, data.selection)
						LineEditWidget.caret_x(caret_positions, selection.focus)
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
								bounds = LineEdit.selection_bounds(string, data.selection)
								if bounds.start != bounds.end {
									selection_x = text_x + LineEditWidget.caret_x(caret_positions, bounds.start)
									selection_width = LineEditWidget.caret_x(caret_positions, bounds.end) - LineEditWidget.caret_x(caret_positions, bounds.start)
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
				var $frame = Frame.from_placement_result(clipped_result)

				handle_pointer_down! : Handler.HandleEvent(state, Event.PointerButtonEvent)
				handle_pointer_down! = |state, pointer| match pointer.button {
					Some(Primary) => if Geometry2d.contains(placement.clip_rect, pointer.position) {
						index = LineEditWidget.closest_caret(caret_positions, pointer.position.x - text_x)
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
						index = LineEditWidget.closest_caret(caret_positions, pointer.position.x - text_x)
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
				$frame = Frame.register(Handler.from_function(handle_event!), $frame)
				$frame
			},
		}
	}
}
