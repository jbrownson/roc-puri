## A small finally-tagless vector canvas for Puri.
##
## Widgets receive a Canvas dictionary and call its effect functions directly.
## No draw-list allocation is required; a recorder is just one interpreter.
import geometry.Geometry2d

PuriCanvas := [].{

	Scalar : F32
	Point : Geometry2d.Point(Scalar)
	Size : Geometry2d.Size(Scalar)
	Rect : Geometry2d.Rect(Scalar)

	WithClip(placed) : placed, Rect, (placed => placed) => placed

	Canvas(placed, paint) : {
		clear! : placed, Size, paint => placed,
		fill_rect! : placed, Rect, paint => placed,
		stroke_rect! : placed, Rect, paint, Scalar => placed,
		fill_text! : placed, Point, paint, Str => placed,
		stroke_line! : placed, Point, Point, paint, Scalar => placed,
		with_clip! : WithClip(placed),
	}
}
