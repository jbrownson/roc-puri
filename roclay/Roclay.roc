## Public continuation-based layout API. The constraint solver lives in the
## package-private `RoclayInternal` module so generated docs stay approachable.
import RoclayInternal

Roclay := [].{
	Scalar : RoclayInternal.Scalar
	Point : RoclayInternal.Point
	Size : RoclayInternal.Size
	Rect : RoclayInternal.Rect
	Insets : RoclayInternal.Insets
	Placement : RoclayInternal.Placement

	Bound : RoclayInternal.Bound
	MinMax : RoclayInternal.MinMax
	AxisSizing : RoclayInternal.AxisSizing
	Sizing : RoclayInternal.Sizing
	Direction : RoclayInternal.Direction
	MainAlign : RoclayInternal.MainAlign
	CrossAlign : RoclayInternal.CrossAlign
	TextWrapMode : RoclayInternal.TextWrapMode
	TextAlign : RoclayInternal.TextAlign
	Clip : RoclayInternal.Clip
	BoxConfig : RoclayInternal.BoxConfig

	Place(output) : RoclayInternal.Place(output)
	PlaceKids(output) : RoclayInternal.PlaceKids(output)
	MeasureText : RoclayInternal.MeasureText
	PlaceTextLine(output) : RoclayInternal.PlaceTextLine(output)
	TextConfig(output) : RoclayInternal.TextConfig(output)
	ContainerInfo : RoclayInternal.ContainerInfo
	PlaceContainer(output) : RoclayInternal.PlaceContainer(output)
	Layout(output) : RoclayInternal.Layout(output)
	Measured(output) : RoclayInternal.Measured(output)

	unbounded : MinMax
	unbounded = RoclayInternal.unbounded

	zero_point : Point
	zero_point = RoclayInternal.zero_point

	zero_size : Size
	zero_size = RoclayInternal.zero_size

	zero_insets : Insets
	zero_insets = RoclayInternal.zero_insets

	default_sizing : Sizing
	default_sizing = RoclayInternal.default_sizing

	default_clip : Clip
	default_clip = RoclayInternal.default_clip

	default_box : BoxConfig
	default_box = RoclayInternal.default_box

	spacer : Size -> Layout(output)
	spacer = |size| RoclayInternal.spacer(size)

	fixed : Size, Place(output) -> Layout(output)
	fixed = |size, place!| RoclayInternal.fixed(size, place!)

	leaf : Size, Place(output) -> Layout(output)
	leaf = |size, place!| RoclayInternal.leaf(size, place!)

	leaf_with_minimum : Size, Size, Place(output) -> Layout(output)
	leaf_with_minimum = |preferred, minimum, place!| RoclayInternal.leaf_with_minimum(preferred, minimum, place!)

	text! : TextConfig(output), Str => Layout(output)
	text! = |config, string| RoclayInternal.text!(config, string)

	box : BoxConfig, List(Layout(output)) -> Layout(output)
	box = |config, children| RoclayInternal.box(config, children)

	container : BoxConfig, PlaceContainer(output), List(Layout(output)) -> Layout(output)
	container = |config, place!, children| RoclayInternal.container(config, place!, children)

	row : List(Layout(output)) -> Layout(output)
	row = |children| RoclayInternal.row(children)

	row_with_gap : Scalar, List(Layout(output)) -> Layout(output)
	row_with_gap = |gap, children| RoclayInternal.row_with_gap(gap, children)

	column : List(Layout(output)) -> Layout(output)
	column = |children| RoclayInternal.column(children)

	column_with_gap : Scalar, List(Layout(output)) -> Layout(output)
	column_with_gap = |gap, children| RoclayInternal.column_with_gap(gap, children)

	padding : Insets, Layout(output) -> Layout(output)
	padding = |insets, layout| RoclayInternal.padding(insets, layout)

	sized : Sizing, Layout(output) -> Layout(output)
	sized = |sizing, layout| RoclayInternal.sized(sizing, layout)

	## Fill the available horizontal space while retaining intrinsic height.
	fill_width : Layout(output) -> Layout(output)
	fill_width = |layout| RoclayInternal.sized({ width: Fill(RoclayInternal.unbounded), height: Fit(RoclayInternal.unbounded) }, layout)

	aspect_ratio : Scalar, Layout(output) -> Layout(output)
	aspect_ratio = |ratio, layout| RoclayInternal.aspect_ratio(ratio, layout)

	decorate : Place(output), Layout(output) -> Layout(output)
	decorate = |place!, layout| RoclayInternal.decorate(place!, layout)

	measure : Layout(output) -> Measured(output)
		where [output.default : output, output.plus : output, output -> output]
	measure = |layout| RoclayInternal.measure(layout)
}
