## A minimal pure single-line editor description rendered through PuriCanvas
## and a Roclay intrinsic leaf. The LineEdit record is an ephemeral value for
## one frame; it says nothing about how an application stores its model.
import roclay.Geometry2d
import Puri
import PuriCanvas
import PuriHandler
import PuriLineEdit
import roclay.Roclay

PuriLineEditWidget := [].{

	Style(paint) : {
		vertical_padding : F32,
		horizontal_padding : F32,
		min_width : F32,
		text_paint : paint,
		caret_paint : paint,
		selection_paint : paint,
	}

	Focus(context) : context, PuriLineEdit.LineEditSelection => context
	Change(context) : context, Str, PuriLineEdit.LineEditSelection => context
	Submit(context) : context => context
	Blur(context) : context => context
	ClipboardReadResult(context) : { context : context, text : Str }
	ClipboardRead(context) : context => ClipboardReadResult(context)
	ClipboardWrite(context) : context, Str => context
	Clipboard(context) : {
		read! : ClipboardRead(context),
		write! : ClipboardWrite(context),
	}

	Interaction(context) := [
		Unfocused(Focus(context)),
		Focused(
			{
				selection : PuriLineEdit.LineEditSelection,
				change! : Change(context),
				submit! : Submit(context),
				blur! : Blur(context),
				clipboard : Clipboard(context),
			},
		),
	]

	LineEdit(context, paint) : {
		style : Style(paint),
		text : Str,
		interaction : Interaction(context),
	}

	Measure : Str => PuriCanvas.TextMetrics

	CaretPosition : {
		index : U64,
		x : F32,
	}

	measure_carets_from! : Measure, Str, U64, List(CaretPosition) => List(CaretPosition)
	measure_carets_from! = |measure!, string, index, positions| {
		metrics = measure!(PuriLineEdit.prefix(string, index))
		next_positions = List.append(positions, { index, x: metrics.width })
		bytes = Str.to_utf8(string)
		if index >= List.len(bytes) {
			next_positions
		} else {
			next = PuriLineEdit.next_boundary(bytes, index)
			PuriLineEditWidget.measure_carets_from!(measure!, string, next, next_positions)
		}
	}

	measure_carets! : Measure, Str => List(CaretPosition)
	measure_carets! = |measure!, string| PuriLineEditWidget.measure_carets_from!(measure!, string, 0, [])

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

	line_edit! : PuriCanvas.Canvas(render, paint), Measure, LineEdit(context, paint) => Roclay.Layout(Puri.Frame(render, context))
	line_edit! = |canvas, measure!, edit| {
		style = edit.style
		string = edit.text
		interaction = edit.interaction
		text_metrics = measure!(string)
		line_metrics = measure!("Mg")
		caret_positions = PuriLineEditWidget.measure_carets!(measure!, string)
		font_height = line_metrics.font_ascent + line_metrics.font_descent
		preferred_size = Geometry2d.size(
			F32.max(style.min_width, text_metrics.width + style.horizontal_padding * 2),
			font_height + style.vertical_padding * 2,
		)
		minimum_size = Geometry2d.size(style.min_width, preferred_size.height)
		Roclay.leaf_with_minimum(
			preferred_size,
			minimum_size,
			|initial_frame, placement| {
				caret_width = 1.5
				caret_offset = match interaction {
					Focused(data) => {
						selection = PuriLineEdit.clamp_selection(string, data.selection)
						PuriLineEditWidget.caret_x(caret_positions, selection.focus)
					}
					Unfocused(_) => 0
				}
				content_width = F32.max(0, placement.rect.width - style.horizontal_padding * 2)
				scroll_x = F32.max(0, caret_offset + caret_width - content_width)
				text_x = placement.rect.x + style.horizontal_padding - scroll_x
				text_top = placement.rect.y + style.vertical_padding
				baseline = text_top + line_metrics.font_ascent
				clipped_render = PuriCanvas.with_clip!(
					canvas,
					initial_frame.render,
					placement.rect,
					|initial_render| {
						var $render = initial_render
						match interaction {
							Focused(data) => {
								bounds = PuriLineEdit.selection_bounds(string, data.selection)
								if bounds.start != bounds.end {
									selection_x = text_x + PuriLineEditWidget.caret_x(caret_positions, bounds.start)
									selection_width = PuriLineEditWidget.caret_x(caret_positions, bounds.end) - PuriLineEditWidget.caret_x(caret_positions, bounds.start)
									$render = PuriCanvas.fill_rect!(canvas, $render, Geometry2d.rect(selection_x, text_top, selection_width, font_height), style.selection_paint)
								}
							}
							Unfocused(_) => {}
						}

						$render = PuriCanvas.fill_text!(canvas, $render, Geometry2d.point(text_x, baseline), style.text_paint, string)

						match interaction {
							Focused(_) => {
								caret_position_x = text_x + caret_offset
								$render = PuriCanvas.fill_rect!(canvas, $render, Geometry2d.rect(caret_position_x, text_top, caret_width, font_height), style.caret_paint)
							}
							Unfocused(_) => {}
						}
						$render
					},
				)
				var $frame = Puri.with_render(clipped_render, initial_frame)

				pointer_down! : PuriHandler.Dispatch(context, PuriHandler.PointerButtonEvent)
				pointer_down! = |context, event| match event.button {
					Some(Primary) => if Geometry2d.contains(placement.rect, event.position) {
						index = PuriLineEditWidget.closest_caret(caret_positions, event.position.x - text_x)
						match interaction {
							Unfocused(focus!) => {
								selection = PuriLineEdit.start_pointer_selection(string, PuriLineEdit.empty_selection, index, event.clicks, Bool.False)
								Handled(focus!(context, selection))
							}
							Focused(data) => {
								selection = PuriLineEdit.start_pointer_selection(string, data.selection, index, event.clicks, event.modifiers.shift)
								Handled((data.change!)(context, string, selection))
							}
						}
					} else {
						Declined
					}
					_ => Declined
				}
				$frame = Puri.register(PuriHandler.on_pointer_down(pointer_down!), $frame)

				match interaction {
					Focused(_) => {
						$frame = Puri.register(PuriHandler.focusable(Bool.True, placement.rect, |context| context), $frame)
					}
					Unfocused(focus!) => {
						request_focus! : context => context
						request_focus! = |context| focus!(context, PuriLineEdit.selection_at_end(string))
						$frame = Puri.register(PuriHandler.focusable(Bool.False, placement.rect, request_focus!), $frame)
					}
				}

				match interaction {
					Focused(data) => {
						pointer_move! : PuriHandler.Dispatch(context, PuriHandler.PointerUpdate)
						pointer_move! = |context, event| if PuriLineEdit.is_dragging(data.selection) {
							index = PuriLineEditWidget.closest_caret(caret_positions, event.position.x - text_x)
							Handled((data.change!)(context, string, PuriLineEdit.continue_drag(string, data.selection, index)))
						} else {
							Declined
						}
						pointer_up! : PuriHandler.Dispatch(context, PuriHandler.PointerButtonEvent)
						pointer_up! = |context, _event| if PuriLineEdit.is_dragging(data.selection) {
							Handled((data.change!)(context, string, PuriLineEdit.end_drag(data.selection)))
						} else {
							Declined
						}
						key! : PuriHandler.Dispatch(context, PuriHandler.KeyEvent)
						key! = |context, event| match (event.state, event.key) {
							(KeyDown, Named(Enter)) => Handled((data.submit!)(context))
							(KeyDown, Named(Escape)) => Handled((data.blur!)(context))
							_ => match PuriLineEdit.handle_key(string, data.selection, event) {
								Edited(next) => Handled((data.change!)(context, next.text, next.selection))
								Copy(selected) => Handled((data.clipboard.write!)(context, selected))
								Cut(cut) => {
									with_clipboard = (data.clipboard.write!)(context, cut.copied)
									Handled((data.change!)(with_clipboard, cut.edit.text, cut.edit.selection))
								}
								Paste => {
									read = (data.clipboard.read!)(context)
									next = PuriLineEdit.replace_selection(string, read.text, data.selection)
									Handled((data.change!)(read.context, next.text, next.selection))
								}
								Ignored => Declined
							}
						}
						$frame = Puri.register(PuriHandler.on_pointer_move(pointer_move!), $frame)
						$frame = Puri.register(PuriHandler.on_pointer_up(pointer_up!), $frame)
						$frame = Puri.register(PuriHandler.on_key(key!), $frame)
					}
					Unfocused(_) => {}
				}
				$frame
			},
		)
	}
}
