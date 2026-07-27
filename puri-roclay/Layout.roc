## Adapt layout-independent Puri widgets to Roclay leaves and decorators.
import geometry.Geometry2d
import puri.Frame as PuriFrame
import roclay.Roclay

Layout := [].{

	leaf : Geometry2d.Size(F32), Geometry2d.Size(F32), PuriFrame.Widget(result, state, event) -> Roclay.Layout(PuriFrame(result, state, event))
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
