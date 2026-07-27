## Public continuation-based layout API. The constraint solver lives in the
## package-private `RoclayInternal` module so generated docs stay approachable.
import geometry.Geometry2d
import RoclayInternal

Roclay := [].{
	Scalar : F32
	Point : Geometry2d.Point(Scalar)
	Size : Geometry2d.Size(Scalar)
	Rect : Geometry2d.Rect(Scalar)
	Insets : Geometry2d.Insets(Scalar)
	Placement : Geometry2d.Placement(Scalar)

	Bound : RoclayInternal.Bound
	MinMax : {
		min : Bound,
		max : Bound,
	}
	AxisSizing : RoclayInternal.AxisSizing
	Sizing : {
		width : AxisSizing,
		height : AxisSizing,
	}
	Direction : RoclayInternal.Direction
	MainAlign : RoclayInternal.MainAlign
	CrossAlign : RoclayInternal.CrossAlign
	TextWrapMode : RoclayInternal.TextWrapMode
	TextAlign : RoclayInternal.TextAlign
	Clip : {
		horizontal : Bool,
		vertical : Bool,
		child_offset : Point,
	}
	BoxConfig : {
		direction : Direction,
		padding : Insets,
		gap : Scalar,
		sizing : Sizing,
		main_align : MainAlign,
		cross_align : CrossAlign,
		clip : Clip,
	}

	Place(output) : Placement => output
	PlaceKids(output) : Point => output
	MeasureText : Str => Size
	PlaceTextLine(output) : U64, Str, Placement => output
	TextConfig(output) : {
		line_height : [Some(Scalar), None],
		wrap_mode : TextWrapMode,
		align : TextAlign,
		measure! : MeasureText,
		place_line! : PlaceTextLine(output),
	}
	ContainerInfo : {
		laid_out_child_size : Size,
		content_size : Size,
	}
	PlaceContainer(output) : Placement, ContainerInfo, PlaceKids(output) => output
	Layout(output) : RoclayInternal.Layout(output)

	## The public boundary between intrinsic measurement and final placement.
	## `size` is the layout's preferred size; `place!` re-solves and realizes it
	## at the caller's chosen placement.
	Measured(output) : {
		size : Size,
		place! : Place(output),
	}

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

	## Solve and realize a layout directly at a known root placement.
	place! : Layout(output), Placement => output
		where [output.default : output, output.plus : output, output -> output]
	place! = |layout, placement| RoclayInternal.place!(layout, placement)

	## Return preferred size plus a continuation for the final placement pass.
	measure : Layout(output) -> Measured(output)
		where [output.default : output, output.plus : output, output -> output]
	measure = |layout| RoclayInternal.measure(layout)
}
