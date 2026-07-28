## A small finally-tagless vector canvas for Puri.
##
## Each operation produces an interpreter result. A direct interpreter can
## perform the operation and return a trivial result; a recording interpreter
## can instead return a command fragment. Results compose through their
## standard `default` and `plus` methods, so rendering need not allocate a
## draw list.
import Geometry

Canvas := [].{

	WithClip(result) : Geometry.Rect, (() => result) => result

	Operations(result, paint) : {
		clear! : Geometry.Size, paint => result,
		fill_rect! : Geometry.Rect, paint => result,
		stroke_rect! : Geometry.Rect, paint, Geometry.Scalar => result,
		fill_text! : Geometry.Point, paint, Str => result,
		stroke_line! : Geometry.Point, Geometry.Point, paint, Geometry.Scalar => result,
		with_clip! : WithClip(result),
	}
}
