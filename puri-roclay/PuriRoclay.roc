## Adapt layout-independent Puri widgets to Roclay leaves and decorators.
import puri.Puri
import roclay.Roclay

PuriRoclay := [].{

	leaf : Puri.MeasuredWidget(result, context) -> Roclay.Layout(Puri.Frame(result, context))
	leaf = |measured| {
		Roclay.leaf_with_minimum(
			measured.preferred_size,
			measured.minimum_size,
			measured.widget!,
		)
	}

	decorate : Puri.Widget(result, context), Roclay.Layout(Puri.Frame(result, context)) -> Roclay.Layout(Puri.Frame(result, context))
	decorate = |widget!, child| {
		Roclay.decorate(
			widget!,
			child,
		)
	}
}
