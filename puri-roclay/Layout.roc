## Adapt layout-independent Puri widgets to Roclay placement phases.
import puri.Frame as PuriFrame
import puri.Geometry as PuriGeometry
import roclay.Roclay

Layout := [].{

	MapFrame(result, state, event) : PuriFrame.Placement, PuriFrame(result, state, event) => PuriFrame(result, state, event)

	leaf : PuriGeometry.Size, PuriGeometry.Size, PuriFrame.Widget(result, state, event) -> Roclay.Layout(PuriFrame(result, state, event))
	leaf = |preferred_size, minimum_size, widget!| {
		Roclay.leaf_with_minimum(
			preferred_size,
			minimum_size,
			widget!,
		)
	}

	## Transform the completed frame produced by this exact layout node without
	## introducing a new node or changing its measurement and placement.
	map_frame : MapFrame(result, state, event), Roclay.Layout(PuriFrame(result, state, event)) -> Roclay.Layout(PuriFrame(result, state, event))
	map_frame = |transform!, child| {
		Roclay.around(
			|placement, place_inner!| transform!(placement, place_inner!()),
			child,
		)
	}

	## Place an additional widget before a subtree. Descendant handlers are added
	## later and therefore receive the first opportunity to handle an event.
	before : PuriFrame.Widget(result, state, event), Roclay.Layout(PuriFrame(result, state, event)) -> Roclay.Layout(PuriFrame(result, state, event))
		where [result.plus : result, result -> result]
	before = |widget!, child| {
		Roclay.before(
			widget!,
			child,
		)
	}

	## Place an additional widget after a subtree. Its handler is added last and
	## therefore receives the first opportunity to handle an event.
	after : PuriFrame.Widget(result, state, event), Roclay.Layout(PuriFrame(result, state, event)) -> Roclay.Layout(PuriFrame(result, state, event))
		where [result.plus : result, result -> result]
	after = |widget!, child| {
		Roclay.after(
			widget!,
			child,
		)
	}
}
