## Continuation-based layout with Clay-compatible geometry.
##
## Roclay owns the layout tree because parent and child sizes must be solved
## together. It does not own rendering: leaf/decorator callbacks receive final
## placements and act immediately. The callback state is explicit, making it
## suitable for a finally-tagless renderer and for a recording test backend.
import Geometry2d

Roclay := [].{

	Scalar : F32
	Point : Geometry2d.Point(Scalar)
	Size : Geometry2d.Size(Scalar)
	Rect : Geometry2d.Rect(Scalar)
	Insets : Geometry2d.Insets(Scalar)
	Placement : Geometry2d.Placement(Scalar)

	Bound := [Bounded(Scalar), Unbounded]

	MinMax : {
		min : Bound,
		max : Bound,
	}

	AxisSizing := [Fit(MinMax), Fixed(Scalar), Fill(MinMax), Percent(Scalar)]

	Sizing : {
		width : AxisSizing,
		height : AxisSizing,
	}

	Direction := [LeftToRight, TopToBottom]
	MainAlign := [MainStart, MainCenter, MainEnd]
	CrossAlign := [CrossStart, CrossCenter, CrossEnd]
	Axis := [Horizontal, Vertical]
	TextWrapMode := [TextWrapWords, TextWrapNewlines, TextWrapNone]
	TextAlign := [TextAlignStart, TextAlignCenter, TextAlignEnd]

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

	Place(state) : state, Placement => state
	PlaceKids(state) : state, Point => state
	MeasureText : Str => Size
	PlaceTextLine(state) : state, U64, Str, Placement => state

	TextConfig(state) : {
		line_height : [Some(Scalar), None],
		wrap_mode : TextWrapMode,
		align : TextAlign,
		measure! : MeasureText,
		place_line! : PlaceTextLine(state),
	}

	TextPlacementConfig(state) : {
		line_height : [Some(Scalar), None],
		wrap_mode : TextWrapMode,
		align : TextAlign,
		place_line! : PlaceTextLine(state),
	}

	TextToken := [TextWord({ text : Str, width : Scalar }), TextNewline]

	TextLine : {
		text : Str,
		width : Scalar,
	}

	TextNode(state) : {
		text : Str,
		config : TextPlacementConfig(state),
		preferred_size : Size,
		natural_line_height : Scalar,
		min_width : Scalar,
		space_width : Scalar,
		tokens : List(TextToken),
		contains_newlines : Bool,
		lines : List(TextLine),
	}

	ContainerInfo : {
		laid_out_child_size : Size,
		content_size : Size,
	}

	PlaceContainer(state) : state, Placement, ContainerInfo, PlaceKids(state) => state

	IntrinsicSize : {
		preferred : Size,
		minimum : Size,
	}

	Content(state) : [Container, Controlled(PlaceContainer(state)), Intrinsic(IntrinsicSize), TextContent(TextNode(state))]

	Layout(state) := {
		config : BoxConfig,
		aspect_ratio : [Some(Scalar), None],
		height_max_override : [Some(Scalar), None],
		content : Content(state),
		placers : List(Place(state)),
		children : List(Layout(state)),
		dimensions : Size,
		min_dimensions : Size,
	}

	Measured(state) : {
		size : Size,
		place! : Place(state),
	}

	unbounded : MinMax
	unbounded = { min: Unbounded, max: Unbounded }

	zero_point : Point
	zero_point = Geometry2d.point(0, 0)

	zero_size : Size
	zero_size = Geometry2d.size(0, 0)

	zero_insets : Insets
	zero_insets = Geometry2d.insets(0, 0, 0, 0)

	default_sizing : Sizing
	default_sizing = { width: Fit(Roclay.unbounded), height: Fit(Roclay.unbounded) }

	default_clip : Clip
	default_clip = { horizontal: Bool.False, vertical: Bool.False, child_offset: Roclay.zero_point }

	default_box : BoxConfig
	default_box = {
		direction: LeftToRight,
		padding: Roclay.zero_insets,
		gap: 0,
		sizing: Roclay.default_sizing,
		main_align: MainStart,
		cross_align: CrossStart,
		clip: Roclay.default_clip,
	}

	spacer : Size -> Layout(state)
	spacer = |intrinsic_size| Roclay.leaf(intrinsic_size, |state, _placement| state)

	fixed : Size, Place(state) -> Layout(state)
	fixed = |intrinsic_size, place!| {
		layout = Roclay.leaf(intrinsic_size, place!)
		Roclay.sized({ width: Fixed(intrinsic_size.width), height: Fixed(intrinsic_size.height) }, layout)
	}

	leaf : Size, Place(state) -> Layout(state)
	leaf = |intrinsic_size, place!| Roclay.leaf_with_minimum(intrinsic_size, intrinsic_size, place!)

	## An opaque leaf whose drawing can adapt when layout allocates less than
	## its preferred size. Existing `leaf` behavior is the special case where
	## preferred and minimum sizes are equal.
	leaf_with_minimum : Size, Size, Place(state) -> Layout(state)
	leaf_with_minimum = |preferred_size, minimum_size, place!| {
		config: Roclay.default_box,
		aspect_ratio: None,
		height_max_override: None,
		content: Intrinsic({ preferred: preferred_size, minimum: minimum_size }),
		placers: [place!],
		children: [],
		dimensions: Roclay.zero_size,
		min_dimensions: Roclay.zero_size,
	}

	## Measure text eagerly, then defer width-sensitive wrapping until the
	## horizontal layout pass. Rendering remains a direct per-line continuation.
	text! : TextConfig(state), Str => Layout(state)
	text! = |config, string| {
		text_node = Roclay.measure_text_node!(config, string)
		{
			config: Roclay.default_box,
			aspect_ratio: None,
			height_max_override: None,
			content: TextContent(text_node),
			placers: [],
			children: [],
			dimensions: Roclay.zero_size,
			min_dimensions: Roclay.zero_size,
		}
	}

	box : BoxConfig, List(Layout(state)) -> Layout(state)
	box = |config, children| {
		config,
		aspect_ratio: None,
		height_max_override: None,
		content: Container,
		placers: [],
		children,
		dimensions: Roclay.zero_size,
		min_dimensions: Roclay.zero_size,
	}

	container : BoxConfig, PlaceContainer(state), List(Layout(state)) -> Layout(state)
	container = |config, place_container!, children| {
		config,
		aspect_ratio: None,
		height_max_override: None,
		content: Controlled(place_container!),
		placers: [],
		children,
		dimensions: Roclay.zero_size,
		min_dimensions: Roclay.zero_size,
	}

	row : List(Layout(state)) -> Layout(state)
	row = |children| Roclay.box(Roclay.default_box, children)

	row_with_gap : Scalar, List(Layout(state)) -> Layout(state)
	row_with_gap = |gap, children| Roclay.box({ ..Roclay.default_box, gap }, children)

	column : List(Layout(state)) -> Layout(state)
	column = |children| Roclay.box({ ..Roclay.default_box, direction: TopToBottom }, children)

	column_with_gap : Scalar, List(Layout(state)) -> Layout(state)
	column_with_gap = |gap, children| Roclay.box({ ..Roclay.default_box, direction: TopToBottom, gap }, children)

	padding : Insets, Layout(state) -> Layout(state)
	padding = |insets, child| Roclay.box({ ..Roclay.default_box, padding: insets }, [child])

	sized : Sizing, Layout(state) -> Layout(state)
	sized = |sizing, layout| { ..layout, config: { ..layout.config, sizing } }

	aspect_ratio : Scalar, Layout(state) -> Layout(state)
	aspect_ratio = |ratio, layout| { ..layout, aspect_ratio: Some(ratio) }

	decorate : Place(state), Layout(state) -> Layout(state)
	decorate = |place!, layout| { ..layout, placers: List.append(layout.placers, place!) }

	measure : Layout(state) -> Measured(state)
	measure = |source| {
		measured = Roclay.layout_node(None, source)
		{
			size: measured.dimensions,
			place!: |state, placement| {
				root_size = Geometry2d.size(placement.rect.width, placement.rect.height)
				Roclay.place_layout!(state, placement, Roclay.layout_node(Some(root_size), source))
			},
		}
	}

	layout_node : [Some(Size), None], Layout(state) -> Layout(state)
	layout_node = |root_size, source| {
		closed = Roclay.close_node(source)
		root = match root_size {
			Some(size) => { ..closed, dimensions: size }
			None => closed
		}
		Roclay.layout_tree(root)
	}

	layout_tree : Layout(state) -> Layout(state)
	layout_tree = |root| {
		after_horizontal = Roclay.size_along_axis(Horizontal, root)
		wrapped_text = Roclay.map_nodes(after_horizontal, Roclay.wrap_node_text)
		aspect_heights = Roclay.map_nodes(wrapped_text, Roclay.scale_aspect_height)
		propagated_heights = Roclay.propagate_resolved_heights(aspect_heights)
		after_vertical = Roclay.size_along_axis(Vertical, propagated_heights)
		Roclay.map_nodes(after_vertical, Roclay.scale_aspect_width)
	}

	map_nodes : Layout(state), (Layout(state) -> Layout(state)) -> Layout(state)
	map_nodes = |node, change| {
		var $children = []
		for child in node.children {
			$children = List.append($children, Roclay.map_nodes(child, change))
		}
		change({ ..node, children: $children })
	}

	close_node : Layout(state) -> Layout(state)
	close_node = |node| {
		var $children = []
		for child in node.children {
			$children = List.append($children, Roclay.close_node(child))
		}
		with_children = { ..node, children: $children }
		closed = match node.content {
			Intrinsic(intrinsic_size) => { ..with_children, dimensions: intrinsic_size.preferred, min_dimensions: intrinsic_size.minimum }
			TextContent(text_node) => {
				..with_children,
				dimensions: text_node.preferred_size,
				min_dimensions: Geometry2d.size(text_node.min_width, text_node.preferred_size.height),
			}
			Container => Roclay.close_container(with_children)
			Controlled(_) => Roclay.close_container(with_children)
		}
		Roclay.update_missing_aspect(Roclay.close_node_sizing(closed))
	}

	close_container : Layout(state) -> Layout(state)
	close_container = |node| {
		content_size = Roclay.container_content_size(node.config.direction, node.config.gap, node.children, Bool.False)
		min_content_size = Roclay.container_content_size(node.config.direction, node.config.gap, node.children, Bool.True)
		{
			..node,
			dimensions: Roclay.expand_size_f32(node.config.padding, content_size),
			min_dimensions: Roclay.close_container_min_dimensions(node.config, min_content_size),
		}
	}

	container_content_size : Direction, Scalar, List(Layout(state)), Bool -> Size
	container_content_size = |direction, gap, children, use_min| {
		primary_axis = Roclay.direction_axis(direction)
		cross_axis = Roclay.other_axis(primary_axis)
		var $primary = 0
		var $cross = 0
		for child in children {
			size = if use_min child.min_dimensions else child.dimensions
			$primary = $primary + Roclay.axis_size(primary_axis, size)
			$cross = F32.max($cross, Roclay.axis_size(cross_axis, size))
		}
		with_gaps = $primary + Roclay.gap_size(gap, List.len(children))
		Roclay.size_from_axes(primary_axis, with_gaps, $cross)
	}

	close_container_min_dimensions : BoxConfig, Size -> Size
	close_container_min_dimensions = |config, content_size| {
		primary_axis = Roclay.direction_axis(config.direction)
		cross_axis = Roclay.other_axis(primary_axis)
		primary = if Roclay.box_clips_axis(primary_axis, config) {
			Roclay.axis_padding(primary_axis, config.padding)
		} else {
			Roclay.axis_size(primary_axis, content_size) + Roclay.axis_padding(primary_axis, config.padding)
		}
		cross = if Roclay.box_clips_axis(cross_axis, config) {
			0
		} else {
			Roclay.axis_size(cross_axis, content_size) + Roclay.axis_padding(cross_axis, config.padding)
		}
		Roclay.size_from_axes(primary_axis, primary, cross)
	}

	close_node_sizing : Layout(state) -> Layout(state)
	close_node_sizing = |node| {
		{
			..node,
			dimensions: {
				width: Roclay.close_axis_size(node.config.sizing.width, node.dimensions.width),
				height: Roclay.close_axis_size(node.config.sizing.height, node.dimensions.height),
			},
			min_dimensions: {
				width: Roclay.close_axis_min_size(node.config.sizing.width, node.min_dimensions.width),
				height: Roclay.close_axis_min_size(node.config.sizing.height, node.min_dimensions.height),
			},
		}
	}

	close_axis_size : AxisSizing, Scalar -> Scalar
	close_axis_size = |sizing, value| match sizing {
		Percent(_) => 0
		_ => Roclay.clamp_axis(sizing, value)
	}

	close_axis_min_size : AxisSizing, Scalar -> Scalar
	close_axis_min_size = |sizing, value| match sizing {
		Percent(_) => value
		_ => Roclay.clamp_axis(sizing, value)
	}

	clamp_axis : AxisSizing, Scalar -> Scalar
	clamp_axis = |sizing, value| {
		min_max = Roclay.sizing_min_max(sizing)
		with_min = match min_max.min {
			Bounded(minimum) => F32.max(minimum, value)
			Unbounded => value
		}
		match min_max.max {
			Bounded(maximum) => F32.min(maximum, with_min)
			Unbounded => with_min
		}
	}

	sizing_min_max : AxisSizing -> MinMax
	sizing_min_max = |sizing| match sizing {
		Fit(min_max) => min_max
		Fill(min_max) => min_max
		Fixed(value) => { min: Bounded(value), max: Bounded(value) }
		Percent(_) => Roclay.unbounded
	}

	axis_min : AxisSizing -> Scalar
	axis_min = |sizing| match Roclay.sizing_min_max(sizing).min {
		Bounded(value) => value
		Unbounded => 0
	}

	axis_max : AxisSizing -> Scalar
	axis_max = |sizing| match Roclay.sizing_min_max(sizing).max {
		Bounded(value) => value
		Unbounded => Roclay.max_float
	}

	update_missing_aspect : Layout(state) -> Layout(state)
	update_missing_aspect = |node| match node.aspect_ratio {
		Some(ratio) => if ratio == 0 {
			node
		} else if node.dimensions.width == 0 and node.dimensions.height != 0 {
			{ ..node, dimensions: { ..node.dimensions, width: node.dimensions.height * ratio } }
		} else if node.dimensions.width != 0 and node.dimensions.height == 0 {
			{ ..node, dimensions: { ..node.dimensions, height: (1 / ratio) * node.dimensions.width } }
		} else {
			node
		}
		None => node
	}

	size_along_axis : Axis, Layout(state) -> Layout(state)
	size_along_axis = |axis, parent| {
		direct_children = Roclay.size_children_along_axis(axis, parent)
		var $children = []
		for child in direct_children {
			$children = List.append($children, Roclay.size_along_axis(axis, child))
		}
		{ ..parent, children: $children }
	}

	size_children_along_axis : Axis, Layout(state) -> List(Layout(state))
	size_children_along_axis = |axis, parent| {
		primary = Roclay.same_axis(axis, Roclay.direction_axis(parent.config.direction))
		parent_size = Roclay.axis_size(axis, parent.dimensions)
		axis_padding_value = Roclay.axis_padding(axis, parent.config.padding)
		var $inner = 0
		var $index = 0
		for child in parent.children {
			child_sizing = Roclay.node_axis_sizing(axis, child)
			child_size = Roclay.axis_size(axis, child.dimensions)
			if primary {
				if $index > 0 {
					$inner = $inner + parent.config.gap
				}
				match child_sizing {
					Percent(_) => {}
					_ => {
						$inner = $inner + child_size
					}
				}
			} else {
				$inner = F32.max($inner, child_size)
			}
			$index = $index + 1
		}
		total_padding_and_gaps = axis_padding_value + if primary Roclay.gap_size(parent.config.gap, List.len(parent.children)) else 0

		var $percent_children = []
		var $inner_with_percent = $inner
		for child in parent.children {
			updated = match Roclay.node_axis_sizing(axis, child) {
				Percent(percent) => {
					percent_size = (parent_size - total_padding_and_gaps) * percent
					if primary {
						$inner_with_percent = $inner_with_percent + percent_size
					}
					Roclay.update_missing_aspect(Roclay.update_node_axis_dimension(axis, percent_size, child))
				}
				_ => child
			}
			$percent_children = List.append($percent_children, updated)
		}

		if primary {
			remaining = parent_size - axis_padding_value - $inner_with_percent
			if remaining < 0 and !(Roclay.node_clips_axis(axis, parent)) {
				Roclay.distribute(axis, remaining, $percent_children, CompressNodes)
			} else if remaining > 0 {
				Roclay.distribute(axis, remaining, $percent_children, GrowNodes)
			} else {
				$percent_children
			}
		} else {
			Roclay.resolve_cross_axis(axis, parent, parent_size, axis_padding_value, $inner, $percent_children)
		}
	}

	DistributionMode := [GrowNodes, CompressNodes]

	distribute : Axis, Scalar, List(Layout(state)), DistributionMode -> List(Layout(state))
	distribute = |axis, remaining, children, mode| {
		var $active_indices = []
		var $index = 0
		for child in children {
			if Roclay.distribution_active(mode, axis, child) {
				$active_indices = List.append($active_indices, $index)
			}
			$index = $index + 1
		}
		Roclay.distribute_active(axis, remaining, children, mode, $active_indices)
	}

	distribute_active : Axis, Scalar, List(Layout(state)), DistributionMode, List(U64) -> List(Layout(state))
	distribute_active = |axis, remaining, children, mode, active_indices| {
		complete = match mode {
			GrowNodes => remaining <= Roclay.epsilon
			CompressNodes => remaining >= -Roclay.epsilon
		}
		if complete {
			children
		} else if List.is_empty(active_indices) {
			children
		} else {
			step = Roclay.distribution_step(mode, axis, remaining, children, active_indices)
			active_count = U64.to_f32(List.len(active_indices))
			amount = match mode {
				GrowNodes => F32.min(step.frontier_delta, remaining / active_count)
				CompressNodes => F32.max(step.frontier_delta, remaining / active_count)
			}
			pass = Roclay.apply_distribution_pass(mode, axis, step.frontier, amount, remaining, children, active_indices, 0)
			Roclay.distribute_active(axis, pass.remaining, pass.children, mode, pass.active_indices)
		}
	}

	distribution_step : DistributionMode, Axis, Scalar, List(Layout(state)), List(U64) -> { frontier : Scalar, frontier_delta : Scalar }
	distribution_step = |mode, axis, remaining, children, active_indices| match mode {
		GrowNodes => {
			var $smallest = Roclay.max_float
			var $second_smallest = Roclay.max_float
			var $width_to_add = remaining
			for child_index in active_indices {
				match List.get(children, child_index) {
					Ok(child) => {
						size = Roclay.axis_size(axis, child.dimensions)
						if Roclay.float_equal(size, $smallest) {
							{}
						} else if size < $smallest {
							$second_smallest = $smallest
							$smallest = size
						} else {
							$second_smallest = F32.min($second_smallest, size)
							$width_to_add = $second_smallest - $smallest
						}
					}
					Err(_) => {}
				}
			}
			{ frontier: $smallest, frontier_delta: $width_to_add }
		}
		CompressNodes => {
			var $largest = 0
			var $second_largest = 0
			var $width_to_add = remaining
			for child_index in active_indices {
				match List.get(children, child_index) {
					Ok(child) => {
						size = Roclay.axis_size(axis, child.dimensions)
						if Roclay.float_equal(size, $largest) {
							{}
						} else if size > $largest {
							$second_largest = $largest
							$largest = size
						} else {
							$second_largest = F32.max($second_largest, size)
							$width_to_add = $second_largest - $largest
						}
					}
					Err(_) => {}
				}
			}
			{ frontier: $largest, frontier_delta: $width_to_add }
		}
	}

	apply_distribution_pass : DistributionMode, Axis, Scalar, Scalar, Scalar, List(Layout(state)), List(U64), U64 -> { remaining : Scalar, children : List(Layout(state)), active_indices : List(U64) }
	apply_distribution_pass = |mode, axis, frontier, amount, remaining, children, active_indices, position| {
		if position >= List.len(active_indices) {
			{ remaining, children, active_indices }
		} else match List.get(active_indices, position) {
			Err(_) => { remaining, children, active_indices }
			Ok(child_index) => match List.get(children, child_index) {
				Err(_) => Roclay.apply_distribution_pass(mode, axis, frontier, amount, remaining, children, active_indices, position + 1)
				Ok(child) => {
					previous = Roclay.axis_size(axis, child.dimensions)
					if !(Roclay.float_equal(previous, frontier)) {
						Roclay.apply_distribution_pass(mode, axis, frontier, amount, remaining, children, active_indices, position + 1)
					} else {
						bound = match mode {
							GrowNodes => Roclay.node_axis_max(axis, child)
							CompressNodes => Roclay.axis_size(axis, child.min_dimensions)
						}
						resized = match mode {
							GrowNodes => F32.min(previous + amount, bound)
							CompressNodes => F32.max(previous + amount, bound)
						}
						next_children = Roclay.replace_at(children, child_index, Roclay.update_node_axis_dimension(axis, resized, child))
						next_remaining = remaining - (resized - previous)
						at_bound = match mode {
							GrowNodes => resized >= bound
							CompressNodes => resized <= bound
						}
						if at_bound {
							Roclay.apply_distribution_pass(mode, axis, frontier, amount, next_remaining, next_children, Roclay.remove_swapback_at(active_indices, position), position)
						} else {
							Roclay.apply_distribution_pass(mode, axis, frontier, amount, next_remaining, next_children, active_indices, position + 1)
						}
					}
				}
			}
		}
	}

	replace_at : List(element), U64, element -> List(element)
	replace_at = |items, wanted_index, replacement| {
		var $next = []
		var $index = 0
		for item in items {
			$next = List.append($next, if $index == wanted_index replacement else item)
			$index = $index + 1
		}
		$next
	}

	remove_swapback_at : List(element), U64 -> List(element)
	remove_swapback_at = |items, wanted_index| match List.last(items) {
		Err(_) => []
		Ok(last_item) => {
			last_index = List.len(items) - 1
			var $next = []
			var $index = 0
			for item in items {
				if $index < last_index {
					$next = List.append($next, if $index == wanted_index last_item else item)
				}
				$index = $index + 1
			}
			$next
		}
	}

	distribution_active : DistributionMode, Axis, Layout(state) -> Bool
	distribution_active = |mode, axis, child| if !(Roclay.text_node_can_resize(child)) {
		Bool.False
	} else match mode {
		GrowNodes => match Roclay.node_axis_sizing(axis, child) {
			Fill(_) => Bool.True
			_ => Bool.False
		}
		CompressNodes => match Roclay.node_axis_sizing(axis, child) {
			# Clay queues every resizable child for compression. An aspect-ratio
			# pass can leave a dimension below its intrinsic minimum; processing
			# that child then clamps it upward before removing it from the queue.
			Fit(_) => Bool.True
			Fill(_) => Bool.True
			_ => Bool.False
		}
	}

	text_node_can_resize : Layout(state) -> Bool
	text_node_can_resize = |node| match node.content {
		TextContent(text_node) => match text_node.config.wrap_mode {
			TextWrapWords => Bool.True
			_ => Bool.False
		}
		_ => Bool.True
	}

	node_is_text : Layout(state) -> Bool
	node_is_text = |node| match node.content {
		TextContent(_) => Bool.True
		_ => Bool.False
	}

	resolve_cross_axis : Axis, Layout(state), Scalar, Scalar, Scalar, List(Layout(state)) -> List(Layout(state))
	resolve_cross_axis = |axis, parent, parent_size, axis_padding_value, inner_size, children| {
		visible_max = parent_size - axis_padding_value
		max_size = if Roclay.node_clips_axis(axis, parent) F32.max(visible_max, inner_size) else visible_max
		var $next = []
		for child in children {
			updated = if !(Roclay.text_node_can_resize(child)) {
				child
			} else {
				match Roclay.node_axis_sizing(axis, child) {
					Fixed(_) => child
					Percent(_) => child
					Fit(_) => {
						resolved = F32.max(Roclay.axis_size(axis, child.min_dimensions), F32.min(max_size, Roclay.axis_size(axis, child.dimensions)))
						Roclay.update_node_axis_dimension(axis, resolved, child)
					}
					Fill(_) => {
						resolved = F32.max(Roclay.axis_size(axis, child.min_dimensions), F32.min(max_size, Roclay.node_axis_max(axis, child)))
						Roclay.update_node_axis_dimension(axis, resolved, child)
					}
				}
			}
			$next = List.append($next, updated)
		}
		$next
	}

	wrap_node_text : Layout(state) -> Layout(state)
	wrap_node_text = |node| match node.content {
		TextContent(text_node) => {
			wrapped = Roclay.wrap_text_node(node.dimensions.width, text_node)
			line_count = U64.to_f32(List.len(wrapped.lines))
			{
				..node,
				content: TextContent(wrapped),
				dimensions: { ..node.dimensions, height: wrapped.preferred_size.height * line_count },
			}
		}
		_ => node
	}

	scale_aspect_height : Layout(state) -> Layout(state)
	scale_aspect_height = |node| if Roclay.node_is_text(node) {
		node
	} else match node.aspect_ratio {
		Some(ratio) => if ratio == 0 node else {
			height = (1 / ratio) * node.dimensions.width
			{ ..node, dimensions: { ..node.dimensions, height }, height_max_override: Some(height) }
		}
		None => node
	}

	scale_aspect_width : Layout(state) -> Layout(state)
	scale_aspect_width = |node| if Roclay.node_is_text(node) {
		node
	} else match node.aspect_ratio {
		Some(ratio) => if ratio == 0 node else Roclay.update_node_axis_dimension(Horizontal, ratio * node.dimensions.height, node)
		None => node
	}

	propagate_resolved_heights : Layout(state) -> Layout(state)
	propagate_resolved_heights = |node| if Roclay.node_is_text(node) or List.len(node.children) == 0 {
		node
	} else {
		var $children = []
		for child in node.children {
			$children = List.append($children, Roclay.propagate_resolved_heights(child))
		}
		with_children = { ..node, children: $children }
		if Roclay.direction_is_left_to_right(node.config.direction) {
			var $height = with_children.dimensions.height
			for child in $children {
				$height = F32.max($height, child.dimensions.height + node.config.padding.top + node.config.padding.bottom)
			}
			{ ..with_children, dimensions: { ..with_children.dimensions, height: Roclay.clamp_node_height(with_children, $height) } }
		} else {
			var $height = node.config.padding.top + node.config.padding.bottom + Roclay.gap_size(node.config.gap, List.len($children))
			for child in $children {
				$height = $height + child.dimensions.height
			}
			{ ..with_children, dimensions: { ..with_children.dimensions, height: Roclay.clamp_node_height(with_children, $height) } }
		}
	}

	clamp_node_height : Layout(state), Scalar -> Scalar
	clamp_node_height = |node, value| {
		# Clay's sizing union overlays percent on minMax.min, so height
		# propagation temporarily treats Percent(p) as having a minimum of p.
		# Its aspect-height pass may also write the overlaid maximum.
		minimum = match node.config.sizing.height {
			Percent(percent) => percent
			_ => Roclay.node_axis_min(Vertical, node)
		}
		F32.min(Roclay.node_axis_max(Vertical, node), F32.max(minimum, value))
	}

	SegmentBreak := [BreakSpace, BreakNewline, BreakEnd]

	TextSegment : {
		word : Str,
		line_break : SegmentBreak,
	}

	segment_text : Str -> List(TextSegment)
	segment_text = |string| {
		lines = Str.split_on(string, "\n")
		line_count = List.len(lines)
		var $segments = []
		var $line_index = 0
		for line in lines {
			words = Str.split_on(line, " ")
			word_count = List.len(words)
			var $word_index = 0
			for word in words {
				segment_break = if $word_index + 1 < word_count {
					BreakSpace
				} else if $line_index + 1 < line_count {
					BreakNewline
				} else {
					BreakEnd
				}
				$segments = List.append($segments, { word, line_break: segment_break })
				$word_index = $word_index + 1
			}
			$line_index = $line_index + 1
		}
		$segments
	}

	measure_text_node! : TextConfig(state), Str => TextNode(state)
	measure_text_node! = |config, string| {
		space_size = (config.measure!)(" ")
		var $tokens = []
		var $current_width = 0
		var $preferred_width = 0
		var $natural_height = 0
		var $min_width = 0
		var $contains_newlines = Bool.False
		for segment in Roclay.segment_text(string) {
			word_size = if Str.is_empty(segment.word) Roclay.zero_size else (config.measure!)(segment.word)
			$natural_height = F32.max($natural_height, word_size.height)
			$min_width = F32.max($min_width, word_size.width)
			match segment.line_break {
				BreakSpace => {
					word_with_space = Str.concat(segment.word, " ")
					word_width = word_size.width + space_size.width
					$tokens = List.append($tokens, TextWord({ text: word_with_space, width: word_width }))
					$current_width = $current_width + word_width
				}
				BreakNewline => {
					if !(Str.is_empty(segment.word)) {
						$tokens = List.append($tokens, TextWord({ text: segment.word, width: word_size.width }))
					}
					$tokens = List.append($tokens, TextNewline)
					$current_width = $current_width + word_size.width
					$preferred_width = F32.max($preferred_width, $current_width)
					$current_width = 0
					$contains_newlines = Bool.True
				}
				BreakEnd => {
					if !(Str.is_empty(segment.word)) {
						$tokens = List.append($tokens, TextWord({ text: segment.word, width: word_size.width }))
					}
					$current_width = $current_width + word_size.width
					$preferred_width = F32.max($preferred_width, $current_width)
				}
			}
		}
		line_height = match config.line_height {
			Some(value) => value
			None => $natural_height
		}
		placement_config = {
			line_height: config.line_height,
			wrap_mode: config.wrap_mode,
			align: config.align,
			place_line!: config.place_line!,
		}
		{
			text: string,
			config: placement_config,
			preferred_size: Geometry2d.size($preferred_width, line_height),
			natural_line_height: $natural_height,
			min_width: $min_width,
			space_width: space_size.width,
			tokens: $tokens,
			contains_newlines: $contains_newlines,
			lines: [{ text: string, width: $preferred_width }],
		}
	}

	wrap_text_node : Scalar, TextNode(state) -> TextNode(state)
	wrap_text_node = |available_width, text_node| {
		lines = match text_node.config.wrap_mode {
			TextWrapWords => if !(text_node.contains_newlines) and text_node.preferred_size.width <= available_width {
				[{ text: text_node.text, width: text_node.preferred_size.width }]
			} else {
				Roclay.wrap_words(available_width, text_node.space_width, text_node.tokens)
			}
			TextWrapNewlines => Roclay.wrap_newlines(text_node.tokens)
			TextWrapNone => [{ text: text_node.text, width: text_node.preferred_size.width }]
		}
		{ ..text_node, lines }
	}

	trimmed_text_line : Str, Scalar, Scalar -> TextLine
	trimmed_text_line = |string, width, space_width| if Str.ends_with(string, " ") {
		{ text: Str.drop_suffix(string, " "), width: width - space_width }
	} else {
		{ text: string, width }
	}

	wrap_words : Scalar, Scalar, List(TextToken) -> List(TextLine)
	wrap_words = |available_width, space_width, tokens| {
		var $lines = []
		var $current_text = ""
		var $current_width = 0
		for token in tokens {
			match token {
				TextNewline => {
					$lines = List.append($lines, Roclay.trimmed_text_line($current_text, $current_width, space_width))
					$current_text = ""
					$current_width = 0
				}
				TextWord(word) => {
					current_empty = Str.is_empty($current_text)
					would_overflow = $current_width + word.width > available_width
					word_overflows = word.width > available_width
					if current_empty and word_overflows {
						$lines = List.append($lines, { text: word.text, width: word.width })
						$current_text = ""
						$current_width = 0
					} else if !(current_empty) and would_overflow and word_overflows {
						$lines = List.append($lines, Roclay.trimmed_text_line($current_text, $current_width, space_width))
						$lines = List.append($lines, { text: word.text, width: word.width })
						$current_text = ""
						$current_width = 0
					} else if !(current_empty) and would_overflow {
						$lines = List.append($lines, Roclay.trimmed_text_line($current_text, $current_width, space_width))
						$current_text = word.text
						$current_width = word.width
					} else {
						$current_text = Str.concat($current_text, word.text)
						$current_width = $current_width + word.width
					}
				}
			}
		}
		if !(Str.is_empty($current_text)) {
			$lines = List.append($lines, Roclay.trimmed_text_line($current_text, $current_width, space_width))
		}
		$lines
	}

	wrap_newlines : List(TextToken) -> List(TextLine)
	wrap_newlines = |tokens| {
		var $lines = []
		var $current_text = ""
		var $current_width = 0
		for token in tokens {
			match token {
				TextNewline => {
					$lines = List.append($lines, { text: $current_text, width: $current_width })
					$current_text = ""
					$current_width = 0
				}
				TextWord(word) => {
					$current_text = Str.concat($current_text, word.text)
					$current_width = $current_width + word.width
				}
			}
		}
		List.append($lines, { text: $current_text, width: $current_width })
	}

	place_layout! : state, Placement, Layout(state) => state
	place_layout! = |state, placement, node| {
		var $state = state
		for place! in node.placers {
			$state = place!($state, placement)
		}
		$state = Roclay.place_text_node!($state, placement, node)
		match node.content {
			Controlled(place_container!) => {
				info = {
					laid_out_child_size: Roclay.first_child_size(node.children),
					content_size: Roclay.container_content_size(node.config.direction, node.config.gap, node.children, Bool.False),
				}
				place_container!(
					$state,
					placement,
					info,
					|child_state, child_offset| Roclay.place_children!(child_state, placement, node, child_offset),
				)
			}
			_ => Roclay.place_children!($state, placement, node, Roclay.node_child_offset(node))
		}
	}

	place_text_node! : state, Placement, Layout(state) => state
	place_text_node! = |state, placement, node| match node.content {
		TextContent(text_node) => {
			line_height = text_node.preferred_size.height
			line_height_offset = (line_height - text_node.natural_line_height) / 2
			var $line_y = placement.rect.y + line_height_offset
			var $line_index = 0
			var $state = state
			for line in text_node.lines {
				align_offset = match text_node.config.align {
					TextAlignStart => 0
					TextAlignCenter => (node.dimensions.width - line.width) / 2
					TextAlignEnd => node.dimensions.width - line.width
				}
				line_rect = Geometry2d.rect(placement.rect.x + align_offset, $line_y, line.width, line_height)
				line_placement = { rect: line_rect }
				$state = (text_node.config.place_line!)($state, $line_index, line.text, line_placement)
				$line_y = $line_y + line_height
				$line_index = $line_index + 1
			}
			$state
		}
		_ => state
	}

	place_children! : state, Placement, Layout(state), Point => state
	place_children! = |state, placement, node, child_offset| {
		config = node.config
		primary_axis = Roclay.direction_axis(config.direction)
		cross_axis = Roclay.other_axis(primary_axis)
		inner = Geometry2d.inset_rect(config.padding, placement.rect)
		content_primary = Roclay.axis_size(primary_axis, Roclay.container_content_size(config.direction, config.gap, node.children, Bool.False))
		placement_size = Geometry2d.size(placement.rect.width, placement.rect.height)
		extra_primary = F32.max(0, Roclay.axis_size(primary_axis, placement_size) - Roclay.axis_padding(primary_axis, config.padding) - content_primary)
		var $primary_position = Roclay.rect_axis_position(primary_axis, inner) + Roclay.main_alignment_offset(config.main_align, extra_primary)
		var $state = state
		for child in node.children {
			child_size = child.dimensions
			child_cross = Roclay.axis_size(cross_axis, child_size)
			available_cross = Roclay.axis_size(cross_axis, Roclay.shrink_size(config.padding, placement_size))
			cross_position = Roclay.rect_axis_position(cross_axis, inner) + Roclay.cross_alignment_offset(config.cross_align, available_cross, child_cross)
			child_point = Roclay.point_from_axes(primary_axis, $primary_position, cross_position)
			child_rect = Geometry2d.size_rect_at(Roclay.offset_point(child_offset, child_point), child_size)
			child_placement = { rect: child_rect }
			$state = Roclay.place_layout!($state, child_placement, child)
			$primary_position = $primary_position + Roclay.axis_size(primary_axis, child_size) + config.gap
		}
		$state
	}

	first_child_size : List(Layout(state)) -> Size
	first_child_size = |children| match List.get(children, 0) {
		Ok(child) => child.dimensions
		Err(_) => Roclay.zero_size
	}

	direction_axis : Direction -> Axis
	direction_axis = |direction| match direction {
		LeftToRight => Horizontal
		TopToBottom => Vertical
	}

	other_axis : Axis -> Axis
	other_axis = |axis| match axis {
		Horizontal => Vertical
		Vertical => Horizontal
	}

	same_axis : Axis, Axis -> Bool
	same_axis = |left, right| match (left, right) {
		(Horizontal, Horizontal) => Bool.True
		(Vertical, Vertical) => Bool.True
		_ => Bool.False
	}

	direction_is_left_to_right : Direction -> Bool
	direction_is_left_to_right = |direction| match direction {
		LeftToRight => Bool.True
		TopToBottom => Bool.False
	}

	axis_size : Axis, Size -> Scalar
	axis_size = |axis, size| match axis {
		Horizontal => size.width
		Vertical => size.height
	}

	size_from_axes : Axis, Scalar, Scalar -> Size
	size_from_axes = |primary_axis, primary, cross| match primary_axis {
		Horizontal => Geometry2d.size(primary, cross)
		Vertical => Geometry2d.size(cross, primary)
	}

	update_node_axis_dimension : Axis, Scalar, Layout(state) -> Layout(state)
	update_node_axis_dimension = |axis, value, node| match axis {
		Horizontal => { ..node, dimensions: { ..node.dimensions, width: value } }
		Vertical => { ..node, dimensions: { ..node.dimensions, height: value } }
	}

	node_axis_sizing : Axis, Layout(state) -> AxisSizing
	node_axis_sizing = |axis, node| match axis {
		Horizontal => node.config.sizing.width
		Vertical => node.config.sizing.height
	}

	node_axis_min : Axis, Layout(state) -> Scalar
	node_axis_min = |axis, node| Roclay.axis_min(Roclay.node_axis_sizing(axis, node))

	node_axis_max : Axis, Layout(state) -> Scalar
	node_axis_max = |axis, node| match axis {
		Horizontal => Roclay.axis_max(node.config.sizing.width)
		Vertical => match node.height_max_override {
			Some(value) => value
			None => match node.config.sizing.height {
				Percent(_) => 0
				other => Roclay.axis_max(other)
			}
		}
	}

	axis_padding : Axis, Insets -> Scalar
	axis_padding = |axis, insets| match axis {
		Horizontal => insets.left + insets.right
		Vertical => insets.top + insets.bottom
	}

	box_clips_axis : Axis, BoxConfig -> Bool
	box_clips_axis = |axis, config| match axis {
		Horizontal => config.clip.horizontal
		Vertical => config.clip.vertical
	}

	node_clips_axis : Axis, Layout(state) -> Bool
	node_clips_axis = |axis, node| Roclay.box_clips_axis(axis, node.config)

	node_clips : Layout(state) -> Bool
	node_clips = |node| node.config.clip.horizontal or node.config.clip.vertical

	node_child_offset : Layout(state) -> Point
	node_child_offset = |node| if Roclay.node_clips(node) node.config.clip.child_offset else Roclay.zero_point

	expand_size_f32 : Insets, Size -> Size
	expand_size_f32 = |insets, size| {
		width: size.width + insets.left + insets.right,
		height: size.height + insets.top + insets.bottom,
	}

	shrink_size : Insets, Size -> Size
	shrink_size = |insets, size| {
		width: size.width - insets.left - insets.right,
		height: size.height - insets.top - insets.bottom,
	}

	offset_point : Point, Point -> Point
	offset_point = |offset, point| Geometry2d.point(point.x + offset.x, point.y + offset.y)

	gap_size : Scalar, U64 -> Scalar
	gap_size = |gap, count| if count <= 1 0 else gap * U64.to_f32(count - 1)

	rect_axis_position : Axis, Rect -> Scalar
	rect_axis_position = |axis, rect| match axis {
		Horizontal => rect.x
		Vertical => rect.y
	}

	point_from_axes : Axis, Scalar, Scalar -> Point
	point_from_axes = |primary_axis, primary, cross| match primary_axis {
		Horizontal => Geometry2d.point(primary, cross)
		Vertical => Geometry2d.point(cross, primary)
	}

	main_alignment_offset : MainAlign, Scalar -> Scalar
	main_alignment_offset = |align, extra| match align {
		MainStart => 0
		MainCenter => extra / 2
		MainEnd => extra
	}

	cross_alignment_offset : CrossAlign, Scalar, Scalar -> Scalar
	cross_alignment_offset = |align, available, child| match align {
		CrossStart => 0
		CrossCenter => (available - child) / 2
		CrossEnd => available - child
	}

	first_placement : Layout(state) -> Placement
	first_placement = |layout| {
		measured = Roclay.measure(layout)
		Geometry2d.root_placement(Geometry2d.rect(0, 0, measured.size.width, measured.size.height))
	}

	epsilon : Scalar
	epsilon = 0.01

	max_float : Scalar
	max_float = 3.4028234663852886e38

	float_equal : Scalar, Scalar -> Bool
	float_equal = |left, right| {
		difference = left - right
		difference < Roclay.epsilon and difference > -Roclay.epsilon
	}
}

expect {
	layout = Roclay.row_with_gap(3, [Roclay.spacer(Geometry2d.size(10.F32, 5)), Roclay.spacer(Geometry2d.size(20, 8))])
	measured = Roclay.measure(Roclay.padding(Geometry2d.insets(7, 3, 5, 5), layout))
	measured.size == Geometry2d.size(41, 20)
}

expect {
	config = {
		..Roclay.default_box,
		sizing: { width: Fixed(100), height: Fixed(50) },
		cross_align: CrossCenter,
		main_align: MainCenter,
	}
	layout = Roclay.box(config, [Roclay.spacer(Geometry2d.size(20.F32, 10))])
	measured = Roclay.measure(layout)
	measured.size == Geometry2d.size(100, 50)
}

expect {
	config = { ..Roclay.default_box, sizing: { width: Fixed(200), height: Fixed(20) } }
	percent_child = Roclay.sized({ width: Percent(0.5), height: Fixed(10) }, Roclay.spacer(Geometry2d.size(0.F32, 0)))
	fixed_child = Roclay.fixed(Geometry2d.size(20.F32, 10), |state, _| state)
	laid_out = Roclay.layout_node(None, Roclay.box(config, [percent_child, fixed_child]))
	match List.get(laid_out.children, 0) {
		Ok(child) => child.dimensions.width == 100
		Err(_) => Bool.False
	}
}

expect {
	flexible = Roclay.leaf_with_minimum(
		Geometry2d.size(100.F32, 10),
		Geometry2d.size(20, 10),
		|state, _placement| state,
	)
	fill = Roclay.sized({ width: Fill(Roclay.unbounded), height: Fit(Roclay.unbounded) }, flexible)
	fixed = Roclay.fixed(Geometry2d.size(10, 10), |state, _placement| state)
	config = { ..Roclay.default_box, gap: 2, sizing: { width: Fixed(50), height: Fixed(10) } }
	laid_out = Roclay.layout_node(None, Roclay.box(config, [fill, fixed]))
	match (List.get(laid_out.children, 0), List.get(laid_out.children, 1)) {
		(Ok(first), Ok(second)) => first.dimensions.width == 38 and second.dimensions.width == 10
		_ => Bool.False
	}
}

expect {
	tokens = [
		TextWord({ text: "alpha ", width: 6 }),
		TextWord({ text: "beta ", width: 5 }),
		TextWord({ text: "gamma", width: 5 }),
	]
	Roclay.wrap_words(6, 1, tokens) == [
		{ text: "alpha", width: 5 },
		{ text: "beta", width: 4 },
		{ text: "gamma", width: 5 },
	]
}

expect {
	tokens = [TextWord({ text: "alpha", width: 5 }), TextNewline, TextWord({ text: "beta", width: 4 })]
	Roclay.wrap_newlines(tokens) == [{ text: "alpha", width: 5 }, { text: "beta", width: 4 }]
}
