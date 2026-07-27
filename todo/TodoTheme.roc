## The todo demo's RocRay font and color choices, bound to reusable Puri
## widgets. Application composition can use these helpers without repeating
## backend plumbing or hiding widget state and callbacks.
import geometry.Geometry2d
import puri.Frame
import puri.Button
import puri.Canvas
import PuriCanvasRocRay
import puri.Checkbox
import puri.EditableText
import puri.Text
import puri.TextButton
import puri.TextMeasurement
import puri_roclay.Frame as RoclayFrame
import puri_roclay.Widgets as RoclayWidgets
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

	body_canvas : Canvas.Operations(RenderResult, Paint)
	body_canvas = PuriCanvasRocRay.canvas(PuriCanvasRocRay.default_text_style)

	measure_body! : TextMeasurement.Measure
	measure_body! = |string| PuriCanvasRocRay.measure!(PuriCanvasRocRay.default_text_style, string)

	line_edit_style : EditableText.Style(Paint)
	line_edit_style = editable_text_style(Geometry2d.insets(10, 12, 10, 12))

	compact_line_edit_style : EditableText.Style(Paint)
	compact_line_edit_style = editable_text_style(Geometry2d.insets(7, 12, 7, 12))

	editable_text_style : Geometry2d.Insets(F32) -> EditableText.Style(Paint)
	editable_text_style = |padding| {
		padding,
		text_paint: TodoTheme.ink,
		caret_paint: TodoTheme.accent,
		caret_width: 1.5,
		selection_paint: Color.from_hex_rgba(0x4aa9c855),
	}

	field_decoration : RoclayFrame.Decoration(Paint)
	field_decoration = {
		insets: Geometry2d.insets(0, 0, 0, 0),
		background: Some(TodoTheme.field_background),
		border_paint: TodoTheme.field_border,
		border_width: 1,
	}

	task_frame : RoclayFrame.Description(Paint)
	task_frame = {
		padding: Geometry2d.insets(8, 8, 8, 8),
		decoration: {
			insets: Geometry2d.insets(0, 0, 0, 0),
			background: Some(Color.from_hex_rgb(0xe8e3da)),
			border_paint: Color.from_hex_rgb(0xd5cec3),
			border_width: 1,
		},
	}

	checkbox_style : Paint -> Checkbox.Style(Paint)
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

	text_button_style : Paint -> TextButton.Style(Paint)
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

	small_text! : Paint, Str => Roclay.Layout(Frame(RenderResult, state, event))
	small_text! = |paint, text| text_with_style!(small_text_style, paint, text)

	title_text! : Paint, Str => Roclay.Layout(Frame(RenderResult, state, event))
	title_text! = |paint, text| text_with_style!(title_text_style, paint, text)

	text_button! : TextButton.Description(state, Paint) => Roclay.Layout(Frame(RenderResult, state, Button.Events(events)))
	text_button! = |description| RoclayWidgets.text_button!(small_text_canvas, measure_small!, description)

	checkbox! : Checkbox.Description(state, Paint) => Roclay.Layout(Frame(RenderResult, state, Button.Events(events)))
	checkbox! = |description| RoclayWidgets.checkbox!(TodoTheme.body_canvas, TodoTheme.measure_body!, description)

	line_edit! : EditableText.Description(state, Paint) => Roclay.Layout(Frame(RenderResult, state, EditableText.Events(events)))
	line_edit! = |description| {
		editable_text = RoclayWidgets.editable_text!(TodoTheme.body_canvas, TodoTheme.measure_body!, description)
		RoclayFrame.decorate!(TodoTheme.body_canvas, TodoTheme.field_decoration, editable_text)
	}

	task! : Roclay.Layout(Frame(RenderResult, state, event)) -> Roclay.Layout(Frame(RenderResult, state, event))
	task! = |child| RoclayFrame.framed!(TodoTheme.body_canvas, TodoTheme.task_frame, child)
}

small_text_style : PuriCanvasRocRay.TextStyle
small_text_style = { ..PuriCanvasRocRay.default_text_style, size: 19 }

title_text_style : PuriCanvasRocRay.TextStyle
title_text_style = { ..PuriCanvasRocRay.default_text_style, size: 34 }

small_text_canvas : Canvas.Operations(TodoTheme.RenderResult, TodoTheme.Paint)
small_text_canvas = PuriCanvasRocRay.canvas(small_text_style)

measure_small! : TextMeasurement.Measure
measure_small! = |string| PuriCanvasRocRay.measure!(small_text_style, string)

text_with_style! : PuriCanvasRocRay.TextStyle, TodoTheme.Paint, Str => Roclay.Layout(Frame(TodoTheme.RenderResult, state, event))
text_with_style! = |style, paint, text| {
	canvas = PuriCanvasRocRay.canvas(style)
	measure! : TextMeasurement.Measure
	measure! = |string| PuriCanvasRocRay.measure!(style, string)
	RoclayWidgets.text!(canvas, measure!, { text, paint })
}
