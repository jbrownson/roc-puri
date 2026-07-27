## The todo demo's RocRay font and color choices, bound to reusable Puri
## widgets. Application composition can use these helpers without repeating
## backend plumbing or hiding widget state and callbacks.
import geometry.Geometry2d
import puri.Puri
import puri.PuriCanvas
import PuriCanvasRocRay
import puri.PuriCheckbox
import puri.PuriLineEditWidget
import puri.PuriText
import puri.PuriTextButton
import puri_roclay.PuriFrame
import puri_roclay.PuriRoclay
import roclay.Roclay
import rr.Color

TodoTheme := [].{

	RenderResult : PuriCanvasRocRay.RenderResult
	Paint : Color

	background : Color
	background = Color.from_hex_rgb(0xf4f1ea)

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

	body_canvas : PuriCanvas.Canvas(RenderResult, Paint)
	body_canvas = PuriCanvasRocRay.canvas(PuriCanvasRocRay.default_text_style)

	measure_body! : PuriText.Measure
	measure_body! = |string| PuriCanvasRocRay.measure!(PuriCanvasRocRay.default_text_style, string)

	line_edit_style : PuriLineEditWidget.Style(Paint)
	line_edit_style = {
		vertical_padding: 8,
		horizontal_padding: 10,
		min_width: 260,
		text_paint: TodoTheme.ink,
		caret_paint: TodoTheme.accent,
		selection_paint: Color.from_hex_rgba(0x4aa9c855),
	}

	field_frame : PuriFrame.Frame(Paint)
	field_frame = {
		padding: Geometry2d.insets(2, 2, 2, 2),
		insets: Geometry2d.insets(0, 0, 0, 0),
		background: Some(TodoTheme.field_background),
		border_paint: TodoTheme.field_border,
		border_width: 1,
	}

	task_frame : PuriFrame.Frame(Paint)
	task_frame = {
		padding: Geometry2d.insets(8, 8, 8, 8),
		insets: Geometry2d.insets(0, 0, 0, 0),
		background: Some(Color.from_hex_rgb(0xe8e3da)),
		border_paint: Color.from_hex_rgb(0xd5cec3),
		border_width: 1,
	}

	checkbox_style : Paint -> PuriCheckbox.Style(Paint)
	checkbox_style = |text_paint| {
		box_size: 19,
		gap: 11,
		vertical_padding: 5,
		horizontal_padding: 4,
		border_width: 1.5,
		mark_width: 2.4,
		box_paint: TodoTheme.field_background,
		hover_box_paint: Color.from_hex_rgb(0xe2f0f2),
		border_paint: TodoTheme.field_border,
		hover_border_paint: TodoTheme.accent,
		mark_paint: TodoTheme.accent,
		text_paint,
		focus_paint: TodoTheme.accent,
	}

	text_button_style : Paint -> PuriTextButton.Style(Paint)
	text_button_style = |text_paint| {
		padding: Geometry2d.insets(6, 10, 6, 10),
		background_paint: Color.from_hex_rgb(0xfffcf7),
		hover_background_paint: Color.from_hex_rgb(0xe8f2f3),
		border_paint: TodoTheme.field_border,
		hover_border_paint: text_paint,
		focus_border_paint: TodoTheme.accent,
		border_width: 1,
		focus_border_width: 2,
		text_paint,
	}

	small_text! : Paint, Str => Roclay.Layout(Puri.Frame(RenderResult, context))
	small_text! = |paint, text| text_with_style!(small_text_style, paint, text)

	title_text! : Paint, Str => Roclay.Layout(Puri.Frame(RenderResult, context))
	title_text! = |paint, text| text_with_style!(title_text_style, paint, text)

	text_button! : PuriTextButton.TextButton(context, Paint) => Roclay.Layout(Puri.Frame(RenderResult, context))
	text_button! = |description| PuriRoclay.leaf(PuriTextButton.text_button!(small_text_canvas, measure_small!, description))

	checkbox! : PuriCheckbox.Checkbox(context, Paint) => Roclay.Layout(Puri.Frame(RenderResult, context))
	checkbox! = |description| PuriRoclay.leaf(PuriCheckbox.checkbox!(TodoTheme.body_canvas, TodoTheme.measure_body!, description))

	line_edit! : PuriLineEditWidget.LineEdit(context, Paint) => Roclay.Layout(Puri.Frame(RenderResult, context))
	line_edit! = |description| PuriRoclay.leaf(PuriLineEditWidget.line_edit!(TodoTheme.body_canvas, TodoTheme.measure_body!, description))

	field! : Roclay.Layout(Puri.Frame(RenderResult, context)) -> Roclay.Layout(Puri.Frame(RenderResult, context))
	field! = |child| PuriFrame.framed!(TodoTheme.body_canvas, TodoTheme.field_frame, child)

	task! : Roclay.Layout(Puri.Frame(RenderResult, context)) -> Roclay.Layout(Puri.Frame(RenderResult, context))
	task! = |child| PuriFrame.framed!(TodoTheme.body_canvas, TodoTheme.task_frame, child)
}

small_text_style : PuriCanvasRocRay.TextStyle
small_text_style = { ..PuriCanvasRocRay.default_text_style, size: 19 }

title_text_style : PuriCanvasRocRay.TextStyle
title_text_style = { ..PuriCanvasRocRay.default_text_style, size: 34 }

small_text_canvas : PuriCanvas.Canvas(TodoTheme.RenderResult, TodoTheme.Paint)
small_text_canvas = PuriCanvasRocRay.canvas(small_text_style)

measure_small! : PuriText.Measure
measure_small! = |string| PuriCanvasRocRay.measure!(small_text_style, string)

text_with_style! : PuriCanvasRocRay.TextStyle, TodoTheme.Paint, Str => Roclay.Layout(Puri.Frame(TodoTheme.RenderResult, context))
text_with_style! = |style, paint, text| {
	canvas = PuriCanvasRocRay.canvas(style)
	measure! : PuriText.Measure
	measure! = |string| PuriCanvasRocRay.measure!(style, string)
	PuriRoclay.leaf(PuriText.text!(canvas, measure!, { text, paint }))
}
