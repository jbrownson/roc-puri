## A small finally-tagless vector canvas for Puri.
##
## Each operation produces an interpreter result. An immediate interpreter can
## perform the operation and return a trivial result; a recording interpreter
## can instead return a command fragment. Results compose through their
## standard `default` and `plus` methods, so rendering need not allocate a
## draw list.
import geometry.Geometry2d

Canvas := [].{

	Scalar : F32
	Point : Geometry2d.Point(Scalar)
	Size : Geometry2d.Size(Scalar)
	Rect : Geometry2d.Rect(Scalar)

	WithClip(result) : Rect, (() => result) => result

	Operations(result, paint) : {
		clear! : Size, paint => result,
		fill_rect! : Rect, paint => result,
		stroke_rect! : Rect, paint, Scalar => result,
		fill_text! : Point, paint, Str => result,
		stroke_line! : Point, Point, paint, Scalar => result,
		with_clip! : WithClip(result),
	}
}
