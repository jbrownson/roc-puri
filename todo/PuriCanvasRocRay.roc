## A direct PuriCanvas interpreter for RocRay.
##
## RocRay 0.8 exposes Raylib drawing and text measurement on the new Roc
## compiler. The local platform facade adds the scoped scissor primitive needed
## to implement PuriCanvas clipping without changing the upstream host.
import geometry.Geometry2d
import puri.PuriCanvas
import puri.PuriTextMeasurement
import rr.Color
import rr.Draw

PuriCanvasRocRay := [].{

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

	measure! : TextStyle, Str => PuriTextMeasurement.Metrics
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

	with_clip! : PuriCanvas.WithClip(result)
	with_clip! = |rect, draw!| {
		Draw.begin_scissor_raw!(rect.x, rect.y, rect.width, rect.height)
		clipped_result = draw!()
		Draw.end_scissor!()
		clipped_result
	}

	canvas : TextStyle -> PuriCanvas.Canvas(RenderResult, Paint)
	canvas = |text_style| {
		clear!: |_size, paint| {
			Draw.clear!(paint)
			{}
		},
		fill_rect!: |rect, paint| {
			Draw.rectangle_raw!({
				x: rect.x,
				y: rect.y,
				width: rect.width,
				height: rect.height,
				color: paint,
			})
			{}
		},
		stroke_rect!: |rect, paint, width| {
			Draw.rectangle_lines_raw!({
				x: rect.x,
				y: rect.y,
				width: rect.width,
				height: rect.height,
				color: paint,
				thickness: width,
			})
			{}
		},
		fill_text!: |baseline, paint, string| {
			metrics = PuriCanvasRocRay.measure!(text_style, string)
			Draw.text_raw!({
				pos: { x: baseline.x, y: baseline.y - metrics.font_ascent },
				text: string,
				size: text_style.size,
				spacing: text_style.spacing,
				color: paint,
				font: Box.unbox(text_style.font),
			})
			{}
		},
		stroke_line!: |start, end, paint, width| {
			Draw.line_raw!({
				start,
				end,
				color: paint,
				thickness: width,
			})
			{}
		},
		with_clip!: PuriCanvasRocRay.with_clip!,
	}
}
