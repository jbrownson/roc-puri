## Renderer-independent text measurement shared by text-bearing widgets.
import Geometry

TextMeasurement := [].{

	Metrics : {
		width : Geometry.Scalar,
		actual_ascent : Geometry.Scalar,
		actual_descent : Geometry.Scalar,
		font_ascent : Geometry.Scalar,
		font_descent : Geometry.Scalar,
	}

	Measure : Str => Metrics
}
