## Adapt layout-independent Puri widgets to Roclay leaves and decorators.
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

	decorate : PuriFrame.Widget(result, state, event), Roclay.Layout(PuriFrame(result, state, event)) -> Roclay.Layout(PuriFrame(result, state, event))
	decorate = |widget!, child| {
		Roclay.decorate(
			widget!,
			child,
		)
	}
}
