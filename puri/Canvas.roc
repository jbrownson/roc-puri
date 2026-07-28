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

	## Ignore drawing while still executing scoped continuations. This is useful
	## when rebuilding a complete frame solely to obtain its fresh handler.
	silent : () -> Operations(result, paint)
		where [result.default : result]
	silent = || {
		Result : result
		{
			clear!: |_size, _paint| Result.default(),
			fill_rect!: |_rect, _paint| Result.default(),
			stroke_rect!: |_rect, _paint, _width| Result.default(),
			fill_text!: |_baseline, _paint, _string| Result.default(),
			stroke_line!: |_start, _end, _paint, _width| Result.default(),
			with_clip!: |_rect, draw!| draw!(),
		}
	}
}
