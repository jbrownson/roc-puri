## A small finally-tagless vector canvas for Puri.
##
## Widgets receive a Canvas dictionary and call its effect functions directly.
## No draw-list allocation is required; a recorder is just one interpreter.
import Geometry2d

PuriCanvas := [].{

	Scalar : F32
	Point : Geometry2d.Point(Scalar)
	Size : Geometry2d.Size(Scalar)
	Rect : Geometry2d.Rect(Scalar)

	TextMetrics : {
		width : Scalar,
		actual_ascent : Scalar,
		actual_descent : Scalar,
		font_ascent : Scalar,
		font_descent : Scalar,
	}

	MeasureResult(render) : {
		render : render,
		metrics : TextMetrics,
	}

	Draw(render) : render => render
	Clear(render, paint) : render, Size, paint => render
	FillRect(render, paint) : render, Rect, paint => render
	StrokeRect(render, paint) : render, Rect, paint, Scalar => render
	FillText(render, paint) : render, Point, paint, Str => render
	StrokeLine(render, paint) : render, Point, Point, paint, Scalar => render
	WithClip(render) : render, Rect, Draw(render) => render
	MeasureText(render) : render, Str => MeasureResult(render)

	Canvas(render, paint) : {
		clear! : Clear(render, paint),
		fill_rect! : FillRect(render, paint),
		stroke_rect! : StrokeRect(render, paint),
		fill_text! : FillText(render, paint),
		stroke_line! : StrokeLine(render, paint),
		with_clip! : WithClip(render),
		measure_text! : MeasureText(render),
	}

	clear! : Canvas(render, paint), render, Size, paint => render
	clear! = |canvas, render, size, paint| (canvas.clear!)(render, size, paint)

	fill_rect! : Canvas(render, paint), render, Rect, paint => render
	fill_rect! = |canvas, render, rect, paint| (canvas.fill_rect!)(render, rect, paint)

	stroke_rect! : Canvas(render, paint), render, Rect, paint, Scalar => render
	stroke_rect! = |canvas, render, rect, paint, width| (canvas.stroke_rect!)(render, rect, paint, width)

	fill_text! : Canvas(render, paint), render, Point, paint, Str => render
	fill_text! = |canvas, render, at, paint, string| (canvas.fill_text!)(render, at, paint, string)

	stroke_line! : Canvas(render, paint), render, Point, Point, paint, Scalar => render
	stroke_line! = |canvas, render, start, end, paint, width| (canvas.stroke_line!)(render, start, end, paint, width)

	with_clip! : Canvas(render, paint), render, Rect, Draw(render) => render
	with_clip! = |canvas, render, rect, draw!| (canvas.with_clip!)(render, rect, draw!)

	measure_text! : Canvas(render, paint), render, Str => MeasureResult(render)
	measure_text! = |canvas, render, string| (canvas.measure_text!)(render, string)
}
