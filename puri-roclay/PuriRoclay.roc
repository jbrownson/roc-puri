## Adapt layout-independent Puri widgets to Roclay leaves and decorators.
import puri.Puri
import roclay.Roclay

PuriRoclay := [].{

	leaf : Puri.MeasuredWidget(result, state, event) -> Roclay.Layout(Puri.Frame(result, state, event))
	leaf = |measured| {
		Roclay.leaf_with_minimum(
			measured.preferred_size,
			measured.minimum_size,
			measured.widget!,
		)
	}

	decorate : Puri.Widget(result, state, event), Roclay.Layout(Puri.Frame(result, state, event)) -> Roclay.Layout(Puri.Frame(result, state, event))
	decorate = |widget!, child| {
		Roclay.decorate(
			widget!,
			child,
		)
	}
}
