## A direct Canvas interpreter for RocRay.
##
## This belongs in a reusable Puri–RocRay integration package, not Todo. It is
## app-local because current Roc packages cannot depend on the selected
## platform or import its `rr` modules. See ../ROC_NOTES.md.
##
## RocRay 0.9 supplies frame-scoped drawing, text measurement, and nested
## scissor scopes. A visible interpreter captures the current frame authority;
## the silent interpreter used by EventLoop remains platform-independent.
import geometry.Geometry2d
import puri.Canvas
import puri.TextMeasurement
import rr.Color
import rr.Draw

RocRayCanvas := [].{

	RenderResult := {}.{
		default : () -> RenderResult
		default = || {}

		plus : RenderResult, RenderResult -> RenderResult
		plus = |_earlier, _later| {}
	}
	Paint : Color

	TextStyle : {
		size : F32,
		spacing : F32,
		font : Draw.Font,
	}

	default_text_style : TextStyle
	default_text_style = {
		size: 24,
		spacing: Draw.default_spacing,
		font: Draw.default_font,
	}

	measure! : TextStyle, Str => TextMeasurement.Metrics
	measure! = |text_style, string| {
		size = Draw.measure_text!({
			text: string,
			size: text_style.size,
			spacing: text_style.spacing,
			font: text_style.font,
		})
		# Raylib exposes a line box but not font ascent/descent. Keep this
		# approximation in the backend so widgets remain renderer-independent.
		ascent = size.height * 0.8
		descent = size.height - ascent
		{
			width: size.width,
			actual_ascent: ascent,
			actual_descent: descent,
			font_ascent: ascent,
			font_descent: descent,
		}
	}

	## Scope any placement output under RocRay's current-frame scissor. This is
	## more general than the Canvas operation because containers may produce a
	## complete Puri Frame, not only a rendering result.
	with_clip! : Draw.Frame, Geometry2d.Rect, (() => result) => result
	with_clip! = |frame, rect, draw!| Draw.with_scissor!(frame, rect, |_clipped_frame| draw!())

	canvas : TextStyle, Draw.Frame -> Canvas.Operations(RenderResult, Paint)
	canvas = |text_style, frame| {
		clear!: |size, paint| {
			# RocRay 0.9's hosted clear currently leaves the native framebuffer
			# black. A full-frame rectangle has the same Canvas semantics.
			Draw.rectangle_raw!(
				frame,
				{
					x: 0,
					y: 0,
					width: size.width,
					height: size.height,
					color: paint,
				},
			)
			{}
		},
		fill_rect!: |rect, paint| {
			Draw.rectangle_raw!(
				frame,
				{
					x: rect.x,
					y: rect.y,
					width: rect.width,
					height: rect.height,
					color: paint,
				},
			)
			{}
		},
		stroke_rect!: |rect, paint, width| {
			Draw.rectangle_lines_raw!(
				frame,
				{
					x: rect.x,
					y: rect.y,
					width: rect.width,
					height: rect.height,
					color: paint,
					thickness: width,
				},
			)
			{}
		},
		fill_text!: |baseline, paint, string| {
			metrics = RocRayCanvas.measure!(text_style, string)
			Draw.text_raw!(
				frame,
				{
					pos: { x: baseline.x, y: baseline.y - metrics.font_ascent },
					text: string,
					size: text_style.size,
					spacing: text_style.spacing,
					color: paint,
					font: text_style.font,
				},
			)
			{}
		},
		stroke_line!: |start, end, paint, width| {
			Draw.line_raw!(
				frame,
				{
					start,
					end,
					color: paint,
					thickness: width,
				},
			)
			{}
		},
		with_clip!: |rect, draw!| RocRayCanvas.with_clip!(frame, rect, draw!),
	}
}
