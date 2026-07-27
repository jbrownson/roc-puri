## Adapt layout-independent Puri widgets to Roclay leaves and decorators.
import puri.Frame as PuriFrame
import roclay.Roclay

Layout := [].{

	leaf : PuriFrame.MeasuredWidget(result, state, event) -> Roclay.Layout(PuriFrame(result, state, event))
	leaf = |measured| {
		Roclay.leaf_with_minimum(
			measured.preferred_size,
			measured.minimum_size,
			measured.widget!,
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
