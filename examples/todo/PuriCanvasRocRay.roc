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

	Placed : {}
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

	with_clip! : PuriCanvas.WithClip(state)
	with_clip! = |state, rect, draw!| {
		Draw.begin_scissor_raw!(rect.x, rect.y, rect.width, rect.height)
		result = draw!(state)
		Draw.end_scissor!()
		result
	}

	canvas : TextStyle -> PuriCanvas.Canvas(Placed, Paint)
	canvas = |text_style| {
		clear!: |placed, _size, paint| {
			Draw.clear!(paint)
			placed
		},
		fill_rect!: |placed, rect, paint| {
			Draw.rectangle_raw!({
				x: rect.x,
				y: rect.y,
				width: rect.width,
				height: rect.height,
				color: paint,
			})
			placed
		},
		stroke_rect!: |placed, rect, paint, width| {
			Draw.rectangle_lines_raw!({
				x: rect.x,
				y: rect.y,
				width: rect.width,
				height: rect.height,
				color: paint,
				thickness: width,
			})
			placed
		},
		fill_text!: |placed, baseline, paint, string| {
			metrics = PuriCanvasRocRay.measure!(text_style, string)
			Draw.text_raw!({
				pos: { x: baseline.x, y: baseline.y - metrics.font_ascent },
				text: string,
				size: text_style.size,
				spacing: text_style.spacing,
				color: paint,
				font: Box.unbox(text_style.font),
			})
			placed
		},
		stroke_line!: |placed, start, end, paint, width| {
			Draw.line_raw!({
				start,
				end,
				color: paint,
				thickness: width,
			})
			placed
		},
		with_clip!: PuriCanvasRocRay.with_clip!,
	}
}
