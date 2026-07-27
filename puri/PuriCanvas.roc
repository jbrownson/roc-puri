## A small finally-tagless vector canvas for Puri.
##
## `result` is the interpreter's accumulated result. Each operation may perform
## effects and transform it directly. RocRay uses `{}` because drawing happens
## immediately; the test interpreter accumulates a command recording. A
## production interpreter therefore need not allocate a draw list.
import geometry.Geometry2d

PuriCanvas := [].{

	Scalar : F32
	Point : Geometry2d.Point(Scalar)
	Size : Geometry2d.Size(Scalar)
	Rect : Geometry2d.Rect(Scalar)

	WithClip(result) : result, Rect, (result => result) => result

	Canvas(result, paint) : {
		clear! : result, Size, paint => result,
		fill_rect! : result, Rect, paint => result,
		stroke_rect! : result, Rect, paint, Scalar => result,
		fill_text! : result, Point, paint, Str => result,
		stroke_line! : result, Point, Point, paint, Scalar => result,
		with_clip! : WithClip(result),
	}
}
