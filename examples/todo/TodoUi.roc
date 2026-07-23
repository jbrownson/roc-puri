import geometry.Geometry2d
import puri.Puri
import puri.PuriButton
import puri.PuriCanvas
import PuriCanvasRocRay
import puri.PuriCheckbox
import puri.PuriFrame
import puri.PuriHandler
import puri.PuriInteract
import puri.PuriLineEdit
import puri.PuriLineEditWidget
import puri.PuriScrollView
import Todo
import roclay.Roclay
import rr.Clipboard
import rr.Color

Model : Todo.Model

## Concrete Puri composition for the todo example. The application model and
## platform lifecycle stay in `Todo` and `main` respectively.
TodoUi := [].{
	background : Color
	background = background_color

	ui! : Model, F32, F32, Geometry2d.Point(F32) => Roclay.Layout(Puri.Frame(PuriCanvasRocRay.Render, Model))
	ui! = |model, width, height, pointer_position| build!(model, width, height, pointer_position)
}

body_text : PuriCanvasRocRay.TextStyle
body_text = PuriCanvasRocRay.default_text_style

small_text : PuriCanvasRocRay.TextStyle
small_text = { ..PuriCanvasRocRay.default_text_style, size: 19 }

title_text : PuriCanvasRocRay.TextStyle
title_text = { ..PuriCanvasRocRay.default_text_style, size: 34 }

body_canvas : PuriCanvas.Canvas(PuriCanvasRocRay.Render, Color)
body_canvas = PuriCanvasRocRay.canvas(body_text)

measure_body! : PuriLineEditWidget.Measure
measure_body! = |string| PuriCanvasRocRay.measure!(body_text, string)

background_color : Color
background_color = Color.from_hex_rgb(0xf4f1ea)

ink : Color
ink = Color.from_hex_rgb(0x272522)

muted_ink : Color
muted_ink = Color.from_hex_rgb(0x706b63)

field_background : Color
field_background = Color.white

field_border : Color
field_border = Color.from_hex_rgb(0xaaa39a)

accent : Color
accent = Color.from_hex_rgb(0x176b87)

danger : Color
danger = Color.from_hex_rgb(0x9c3f38)

button_background : Color
button_background = Color.from_hex_rgb(0xfffcf7)

button_hover_background : Color
button_hover_background = Color.from_hex_rgb(0xe8f2f3)

checkbox_hover_background : Color
checkbox_hover_background = Color.from_hex_rgb(0xe2f0f2)

selection_color : Color
selection_color = Color.from_hex_rgba(0x4aa9c855)

line_edit_style : PuriLineEditWidget.Style(Color)
line_edit_style = {
	vertical_padding: 8,
	horizontal_padding: 10,
	min_width: 260,
	text_paint: ink,
	caret_paint: accent,
	selection_paint: selection_color,
}

focus! : Model, PuriLineEdit.LineEditSelection => Model
focus! = |model, selection| Todo.focus_draft(model, selection)

change! : Model, Str, PuriLineEdit.LineEditSelection => Model
change! = |model, draft, selection| Todo.change_draft(model, draft, selection)

submit! : Model => Model
submit! = |model| Todo.submit_draft(model)

blur! : Model => Model
blur! = |model| Todo.clear_focus(model)

clipboard : PuriLineEditWidget.Clipboard(Model)
clipboard = {
	read!: |model| { context: model, text: Clipboard.get_text!() },
	write!: |model, text| {
		Clipboard.set_text!(text)
		model
	},
}

draft_interaction : Model -> PuriLineEditWidget.Interaction(Model)
draft_interaction = |model| match model.focus {
	DraftFocus(selection) => Focused({ selection, change!, submit!, blur!, clipboard })
	_ => Unfocused(focus!)
}

label! : PuriCanvasRocRay.TextStyle, Color, Str => Roclay.Layout(Puri.Frame(PuriCanvasRocRay.Render, Model))
label! = |text_style, paint, string| {
	canvas = PuriCanvasRocRay.canvas(text_style)
	metrics = PuriCanvasRocRay.measure!(text_style, string)
	size = Geometry2d.size(metrics.width, metrics.font_ascent + metrics.font_descent)
	Roclay.leaf(
		size,
		|frame, placement| {
			baseline = Geometry2d.point(placement.rect.x, placement.rect.y + metrics.font_ascent)
			render = PuriCanvas.fill_text!(canvas, frame.render, baseline, paint, string)
			Puri.with_render(render, frame)
		},
	)
}

Surface : {
	fill : Color,
	border : Color,
	border_width : F32,
	padding : Geometry2d.Insets(F32),
}

surface : Surface, Roclay.Layout(Puri.Frame(PuriCanvasRocRay.Render, Model)) -> Roclay.Layout(Puri.Frame(PuriCanvasRocRay.Render, Model))
surface = |style, child| PuriFrame.framed!(
	body_canvas,
	{
		padding: style.padding,
		insets: Geometry2d.insets(0, 0, 0, 0),
		background: Some(style.fill),
		border_paint: style.border,
		border_width: style.border_width,
	},
	child,
)

field_surface : Surface
field_surface = { fill: field_background, border: field_border, border_width: 1, padding: Geometry2d.insets(2, 2, 2, 2) }

task_surface : Surface
task_surface = {
	fill: Color.from_hex_rgb(0xe8e3da),
	border: Color.from_hex_rgb(0xd5cec3),
	border_width: 1,
	padding: Geometry2d.insets(8, 8, 8, 8),
}

fill_width : Roclay.Layout(state) -> Roclay.Layout(state)
fill_width = |layout| Roclay.sized({ width: Fill(Roclay.unbounded), height: Fit(Roclay.unbounded) }, layout)

checkbox_style : Color -> PuriCheckbox.Style(Color)
checkbox_style = |text_paint| {
	box_size: 19,
	gap: 11,
	vertical_padding: 5,
	horizontal_padding: 4,
	border_width: 1.5,
	mark_width: 2.4,
	box_paint: field_background,
	hover_box_paint: checkbox_hover_background,
	border_paint: field_border,
	hover_border_paint: accent,
	mark_paint: accent,
	text_paint,
	focus_paint: accent,
}

TextButton : {
	text : Str,
	text_paint : Color,
	focused : Bool,
	pointer_position : Geometry2d.Point(F32),
	request_focus! : PuriButton.Action(Model),
	activate! : PuriButton.Action(Model),
}

text_button! : TextButton => Roclay.Layout(Puri.Frame(PuriCanvasRocRay.Render, Model))
text_button! = |description| {
	content! : PuriButton.Content(PuriCanvasRocRay.Render, Model)
	content! = |frame, is_focused, is_hovered, placement| {
		background = if is_hovered button_hover_background else button_background
		border = if is_focused accent else if is_hovered description.text_paint else field_border
		var $render = PuriCanvas.fill_rect!(body_canvas, frame.render, placement.rect, background)
		$render = PuriCanvas.stroke_rect!(body_canvas, $render, placement.rect, border, if is_focused 2 else 1)
		Puri.with_render($render, frame)
	}
	button = {
		focused: description.focused,
		pointer_position: Some(description.pointer_position),
		request_focus!: description.request_focus!,
		activate!: description.activate!,
		content!,
	}
	content = Roclay.padding(Geometry2d.insets(6, 10, 6, 10), label!(small_text, description.text_paint, description.text))
	PuriButton.button!(button, content)
}

task_row! : Model, Todo.Task, Geometry2d.Point(F32) => Roclay.Layout(Puri.Frame(PuriCanvasRocRay.Render, Model))
task_row! = |model, item, pointer_position| {
	editing = Todo.is_editing(model, item.id)
	request_toggle! : PuriButton.Action(Model)
	request_toggle! = |context| Todo.focus_toggle(context, item.id)
	toggle! : PuriButton.Action(Model)
	toggle! = |context| Todo.toggle(context, item.id)
	checkbox = {
		style: { ..checkbox_style(if item.completed muted_ink else ink), gap: if editing 0 else 11 },
		label: if editing "" else item.label,
		checked: item.completed,
		focused: Todo.toggle_focused(model, item.id),
		pointer_position: Some(pointer_position),
		request_focus!: request_toggle!,
		toggle!,
	}
	checkbox_base = PuriCheckbox.checkbox!(body_canvas, measure_body!, checkbox)
	checkbox_layout = if editing {
		checkbox_base
	} else {
		start_edit! : PuriButton.Action(Model)
		start_edit! = |context| {
			# The first press toggled normally. Match that toggle on the second
			# press before entering edit mode, so the pair preserves completion.
			untoggled = Todo.toggle(context, item.id)
			Todo.start_edit(untoggled, item.id, PuriLineEdit.selection_at_end(item.label))
		}
		fill_width(PuriInteract.double_clickable(start_edit!, checkbox_base))
	}

	request_edit! : PuriButton.Action(Model)
	request_edit! = |context| Todo.focus_edit(context, item.id)
	edit! : PuriButton.Action(Model)
	edit! = |context| if editing {
		Todo.finish_edit(context, item.id)
	} else {
		Todo.start_edit(context, item.id, PuriLineEdit.selection_at_end(item.label))
	}
	edit_button = text_button!({
		text: if editing "Done" else "Edit",
		text_paint: accent,
		focused: Todo.edit_focused(model, item.id),
		pointer_position,
		request_focus!: request_edit!,
		activate!: edit!,
	})

	request_remove! : PuriButton.Action(Model)
	request_remove! = |context| Todo.focus_remove(context, item.id)
	remove! : PuriButton.Action(Model)
	remove! = |context| Todo.remove(context, item.id)
	remove_button = text_button!({
		text: "Delete",
		text_paint: danger,
		focused: Todo.remove_focused(model, item.id),
		pointer_position,
		request_focus!: request_remove!,
		activate!: remove!,
	})

	row_children = if editing {
		focus_label! : PuriLineEditWidget.Focus(Model)
		focus_label! = |context, selection| Todo.start_edit(context, item.id, selection)
		change_label! : PuriLineEditWidget.Change(Model)
		change_label! = |context, label, selection| Todo.change_label(context, item.id, label, selection)
		finish_edit! : PuriLineEditWidget.Submit(Model)
		finish_edit! = |context| Todo.finish_edit(context, item.id)
		label_interaction = match model.focus {
			TaskEditFocus(data) => if data.id == item.id {
				Focused({ selection: data.selection, change!: change_label!, submit!: finish_edit!, blur!: finish_edit!, clipboard })
			} else {
				Unfocused(focus_label!)
			}
			_ => Unfocused(focus_label!)
		}
		label_edit = {
			style: { ..line_edit_style, vertical_padding: 5, min_width: 120 },
			text: item.label,
			interaction: label_interaction,
		}
		label_edit_layout = fill_width(
			surface(
				field_surface,
				fill_width(PuriLineEditWidget.line_edit!(body_canvas, measure_body!, label_edit)),
			),
		)
		[checkbox_layout, label_edit_layout, edit_button, remove_button]
	} else {
		[checkbox_layout, edit_button, remove_button]
	}

	row_config = {
		..Roclay.default_box,
		gap: 12,
		cross_align: CrossCenter,
		sizing: { width: Fill(Roclay.unbounded), height: Fit(Roclay.unbounded) },
	}
	row = Roclay.box(row_config, row_children)
	fill_width(
		surface(
			task_surface,
			row,
		),
	)
}

build! : Model, F32, F32, Geometry2d.Point(F32) => Roclay.Layout(Puri.Frame(PuriCanvasRocRay.Render, Model))
build! = |model, width, height, pointer_position| {
	edit = {
		style: line_edit_style,
		text: model.draft,
		interaction: draft_interaction(model),
	}
	edit_layout = PuriLineEditWidget.line_edit!(body_canvas, measure_body!, edit)
	field = fill_width(
		surface(
			field_surface,
			fill_width(edit_layout),
		),
	)

	request_add! : PuriButton.Action(Model)
	request_add! = |context| Todo.focus_add(context)
	add! : PuriButton.Action(Model)
	add! = |context| {
		next = Todo.submit_draft(context)
		Todo.focus_draft(next, PuriLineEdit.selection_at_end(next.draft))
	}
	add_button = text_button!({
		text: "Add",
		text_paint: accent,
		focused: Todo.add_focused(model),
		pointer_position,
		request_focus!: request_add!,
		activate!: add!,
	})
	entry_config = {
		..Roclay.default_box,
		gap: 12,
		cross_align: CrossCenter,
		sizing: { width: Fill(Roclay.unbounded), height: Fit(Roclay.unbounded) },
	}
	entry_row = Roclay.box(entry_config, [field, add_button])

	var $task_children = []
	if List.is_empty(model.items) {
		$task_children = List.append($task_children, label!(small_text, muted_ink, "No tasks yet."))
	} else {
		for item in model.items {
			$task_children = List.append($task_children, task_row!(model, item, pointer_position))
		}
	}
	task_column_config = {
		..Roclay.default_box,
		direction: TopToBottom,
		gap: 12,
		sizing: { width: Fill(Roclay.unbounded), height: Fit(Roclay.unbounded) },
	}
	task_column = Roclay.box(task_column_config, $task_children)
	scroll_view = {
		offset: model.scroll_offset,
		scroll_to_end: model.scroll_to_end,
		set_offset!: |context, offset| Todo.set_scroll_offset(context, offset),
	}
	scroll_config = {
		..Roclay.default_box,
		sizing: { width: Fill(Roclay.unbounded), height: Fill(Roclay.unbounded) },
	}
	task_list = PuriScrollView.vertical!(PuriCanvasRocRay.with_clip!, scroll_view, scroll_config, task_column)
	children = [
		label!(title_text, ink, "Puri todo"),
		label!(small_text, muted_ink, "Type a task, then press Enter or choose Add."),
		entry_row,
		task_list,
	]

	root_config = {
		..Roclay.default_box,
		direction: TopToBottom,
		padding: Geometry2d.insets(32, 28, 32, 28),
		gap: 16,
		sizing: { width: Fixed(width), height: Fixed(height) },
	}
	Roclay.box(root_config, children)
}
