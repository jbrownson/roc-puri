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

	Place(state) : RoclayInternal.Place(state)
	PlaceKids(state) : RoclayInternal.PlaceKids(state)
	MeasureText : RoclayInternal.MeasureText
	PlaceTextLine(state) : RoclayInternal.PlaceTextLine(state)
	TextConfig(state) : RoclayInternal.TextConfig(state)
	ContainerInfo : RoclayInternal.ContainerInfo
	PlaceContainer(state) : RoclayInternal.PlaceContainer(state)
	Layout(state) : RoclayInternal.Layout(state)
	Measured(state) : RoclayInternal.Measured(state)

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

	spacer : Size -> Layout(state)
	spacer = |size| RoclayInternal.spacer(size)

	fixed : Size, Place(state) -> Layout(state)
	fixed = |size, place!| RoclayInternal.fixed(size, place!)

	leaf : Size, Place(state) -> Layout(state)
	leaf = |size, place!| RoclayInternal.leaf(size, place!)

	leaf_with_minimum : Size, Size, Place(state) -> Layout(state)
	leaf_with_minimum = |preferred, minimum, place!| RoclayInternal.leaf_with_minimum(preferred, minimum, place!)

	text! : TextConfig(state), Str => Layout(state)
	text! = |config, string| RoclayInternal.text!(config, string)

	box : BoxConfig, List(Layout(state)) -> Layout(state)
	box = |config, children| RoclayInternal.box(config, children)

	container : BoxConfig, PlaceContainer(state), List(Layout(state)) -> Layout(state)
	container = |config, place!, children| RoclayInternal.container(config, place!, children)

	row : List(Layout(state)) -> Layout(state)
	row = |children| RoclayInternal.row(children)

	row_with_gap : Scalar, List(Layout(state)) -> Layout(state)
	row_with_gap = |gap, children| RoclayInternal.row_with_gap(gap, children)

	column : List(Layout(state)) -> Layout(state)
	column = |children| RoclayInternal.column(children)

	column_with_gap : Scalar, List(Layout(state)) -> Layout(state)
	column_with_gap = |gap, children| RoclayInternal.column_with_gap(gap, children)

	padding : Insets, Layout(state) -> Layout(state)
	padding = |insets, layout| RoclayInternal.padding(insets, layout)

	sized : Sizing, Layout(state) -> Layout(state)
	sized = |sizing, layout| RoclayInternal.sized(sizing, layout)

	aspect_ratio : Scalar, Layout(state) -> Layout(state)
	aspect_ratio = |ratio, layout| RoclayInternal.aspect_ratio(ratio, layout)

	decorate : Place(state), Layout(state) -> Layout(state)
	decorate = |place!, layout| RoclayInternal.decorate(place!, layout)

	measure : Layout(state) -> Measured(state)
	measure = |layout| RoclayInternal.measure(layout)
}
