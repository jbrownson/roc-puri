## Adapt layout-independent Puri widgets to Roclay placement phases.
import puri.Frame as PuriFrame
import puri.Geometry as PuriGeometry
import roclay.Roclay

Layout := [].{

	leaf : PuriGeometry.Size, PuriGeometry.Size, PuriFrame.Widget(result, state, event) -> Roclay.Layout(PuriFrame(result, state, event))
	leaf = |preferred_size, minimum_size, widget!| {
		Roclay.leaf_with_minimum(
			preferred_size,
			minimum_size,
			widget!,
		)
	}

	## Place an additional widget after a subtree. Its handler is added last and
	## therefore receives the first opportunity to handle an event.
	after : PuriFrame.Widget(result, state, event), Roclay.Layout(PuriFrame(result, state, event)) -> Roclay.Layout(PuriFrame(result, state, event))
	after = |widget!, child| {
		Roclay.after(
			widget!,
			child,
		)
	}
}
