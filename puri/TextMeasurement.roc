## Renderer-independent text measurement shared by text-bearing widgets.
TextMeasurement := [].{

	Metrics : {
		width : F32,
		actual_ascent : F32,
		actual_descent : F32,
		font_ascent : F32,
		font_descent : F32,
	}

	Measure : Str => Metrics
}
