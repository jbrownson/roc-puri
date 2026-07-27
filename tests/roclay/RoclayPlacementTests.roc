app [main!] {
	test_host: platform "../../test-platform/main.roc",
	geometry: "../../geometry/main.roc",
	roclay: "../../roclay/main.roc",
	support: "./main.roc",
}

## Effectful placement/conformance tests.
##
## The recording state is intentionally an initial encoding, but it exists
## only in this test executable. Roclay itself invokes placement callbacks
## directly, so production backends do not build render-command trees.
import geometry.Geometry2d
import roclay.Roclay
import support.RoclayRecording

NamedRect : {
	name : Str,
	rect : Roclay.Rect,
}

RecordedPlacement : {
	rect : Roclay.Rect,
	clip_rect : Roclay.Rect,
}

NamedRecording : RoclayRecording.Recording(NamedRect)

PlacementRecording : RoclayRecording.Recording(RecordedPlacement)

record : Str -> Roclay.Place(NamedRecording)
record = |name| |placement| RoclayRecording.one({ name, rect: placement.rect })

record_placement : Roclay.Place(PlacementRecording)
record_placement = |placement| RoclayRecording.one(placement)

named : Str, Roclay.Size -> Roclay.Layout(NamedRecording)
named = |name, size| Roclay.leaf(size, record(name))

named_layout : Str, Roclay.Layout(NamedRecording) -> Roclay.Layout(NamedRecording)
named_layout = |name, layout| Roclay.decorate(record(name), layout)

place_at_origin! : Roclay.Layout(NamedRecording), Roclay.Size => List(NamedRect)
place_at_origin! = |layout, root_size| {
	measured = Roclay.measure(layout)
	placement = Geometry2d.root_placement(Geometry2d.rect(0, 0, root_size.width, root_size.height))
	((measured.place!)(placement)).items
}

approx : F32, F32 -> Bool
approx = |left, right| F32.abs(left - right) < 0.001

same_rect : Roclay.Rect, Roclay.Rect -> Bool
same_rect = |left, right| approx(left.x, right.x) and approx(left.y, right.y) and approx(left.width, right.width) and approx(left.height, right.height)

same_placements : List(NamedRect), List(NamedRect) -> Bool
same_placements = |actual, expected| {
	if List.len(actual) != List.len(expected) {
		Bool.False
	} else {
		var $same = Bool.True
		var $index = 0
		for actual_rect in actual {
			match List.get(expected, $index) {
				Ok(expected_rect) => if actual_rect.name != expected_rect.name or !(same_rect(actual_rect.rect, expected_rect.rect)) {
					$same = Bool.False
				}
				Err(_) => {
					$same = Bool.False
				}
			}
			$index = $index + 1
		}
		$same
	}
}

rect : Str, F32, F32, F32, F32 -> NamedRect
rect = |name, x, y, width, height| { name, rect: Geometry2d.rect(x, y, width, height) }

conforms! : Roclay.Layout(NamedRecording), Roclay.Size, List(NamedRect) => Bool
conforms! = |layout, root_size, expected| same_placements(place_at_origin!(layout, root_size), expected)

row_gap_and_padding! : () => Bool
row_gap_and_padding! = || {
	config = { ..Roclay.default_box, padding: Geometry2d.insets(7, 3, 5, 5), gap: 3 }
	layout = named_layout("root", Roclay.box(config, [named("a", Geometry2d.size(10, 5)), named("b", Geometry2d.size(20, 8))]))
	conforms!(layout, Geometry2d.size(41, 20), [rect("root", 0, 0, 41, 20), rect("a", 5, 7, 10, 5), rect("b", 18, 7, 20, 8)])
}

column_gap_and_padding! : () => Bool
column_gap_and_padding! = || {
	config = { ..Roclay.default_box, direction: TopToBottom, padding: Geometry2d.insets(3, 8, 10, 2), gap: 4 }
	layout = named_layout("root", Roclay.box(config, [named("a", Geometry2d.size(10, 5)), named("b", Geometry2d.size(20, 8))]))
	conforms!(layout, Geometry2d.size(30, 30), [rect("root", 0, 0, 30, 30), rect("a", 2, 3, 10, 5), rect("b", 2, 12, 20, 8)])
}

fixed_box_centers_child! : () => Bool
fixed_box_centers_child! = || {
	config = {
		..Roclay.default_box,
		sizing: { width: Fixed(100), height: Fixed(50) },
		main_align: MainCenter,
		cross_align: CrossCenter,
	}
	layout = named_layout("root", Roclay.box(config, [named("a", Geometry2d.size(20, 10))]))
	conforms!(layout, Geometry2d.size(100, 50), [rect("root", 0, 0, 100, 50), rect("a", 40, 20, 20, 10)])
}

percent_child! : () => Bool
percent_child! = || {
	config = { ..Roclay.default_box, sizing: { width: Fixed(200), height: Fixed(20) } }
	a = Roclay.sized({ width: Percent(0.5), height: Fixed(10) }, named("a", Geometry2d.size(10, 10)))
	layout = named_layout("root", Roclay.box(config, [a, named("b", Geometry2d.size(20, 10))]))
	conforms!(layout, Geometry2d.size(200, 20), [rect("root", 0, 0, 200, 20), rect("a", 0, 0, 100, 10), rect("b", 100, 0, 20, 10)])
}

grow_main_axis! : () => Bool
grow_main_axis! = || {
	config = { ..Roclay.default_box, sizing: { width: Fixed(100), height: Fixed(20) }, gap: 10 }
	b = Roclay.sized({ width: Fill(Roclay.unbounded), height: Fixed(10) }, named("b", Geometry2d.size(0, 10)))
	layout = named_layout("root", Roclay.box(config, [named("a", Geometry2d.size(20, 10)), b]))
	conforms!(layout, Geometry2d.size(100, 20), [rect("root", 0, 0, 100, 20), rect("a", 0, 0, 20, 10), rect("b", 30, 0, 70, 10)])
}

grow_cross_axis! : () => Bool
grow_cross_axis! = || {
	config = { ..Roclay.default_box, sizing: { width: Fixed(100), height: Fixed(50) } }
	a = Roclay.sized({ width: Fixed(10), height: Fill(Roclay.unbounded) }, named("a", Geometry2d.size(10, 0)))
	layout = named_layout("root", Roclay.box(config, [a]))
	conforms!(layout, Geometry2d.size(100, 50), [rect("root", 0, 0, 100, 50), rect("a", 0, 0, 10, 50)])
}

clamp_grow! : () => Bool
clamp_grow! = || {
	config = { ..Roclay.default_box, sizing: { width: Fixed(100), height: Fixed(20) } }
	max_30 = { min: Unbounded, max: Bounded(30) }
	b = Roclay.sized({ width: Fill(max_30), height: Fixed(10) }, named("b", Geometry2d.size(0, 10)))
	layout = named_layout("root", Roclay.box(config, [named("a", Geometry2d.size(20, 10)), b]))
	conforms!(layout, Geometry2d.size(100, 20), [rect("root", 0, 0, 100, 20), rect("a", 0, 0, 20, 10), rect("b", 20, 0, 30, 10)])
}

aspect_ratio_width_drives_height! : () => Bool
aspect_ratio_width_drives_height! = || {
	config = { ..Roclay.default_box, sizing: { width: Fixed(100), height: Fixed(100) } }
	a = Roclay.aspect_ratio(2, Roclay.sized({ width: Fixed(40), height: Fit(Roclay.unbounded) }, named("a", Geometry2d.size(0, 0))))
	layout = named_layout("root", Roclay.box(config, [a]))
	conforms!(layout, Geometry2d.size(100, 100), [rect("root", 0, 0, 100, 100), rect("a", 0, 0, 40, 20)])
}

aspect_ratio_height_drives_width! : () => Bool
aspect_ratio_height_drives_width! = || {
	config = { ..Roclay.default_box, direction: TopToBottom, sizing: { width: Fixed(100), height: Fixed(100) } }
	a = Roclay.aspect_ratio(2, Roclay.sized({ width: Fit(Roclay.unbounded), height: Fixed(30) }, named("a", Geometry2d.size(0, 0))))
	layout = named_layout("root", Roclay.box(config, [a]))
	conforms!(layout, Geometry2d.size(100, 100), [rect("root", 0, 0, 100, 100), rect("a", 0, 0, 60, 30)])
}

aspect_ratio_percent_width! : () => Bool
aspect_ratio_percent_width! = || {
	config = { ..Roclay.default_box, sizing: { width: Fixed(200), height: Fixed(100) } }
	a = Roclay.aspect_ratio(2, Roclay.sized({ width: Percent(0.5), height: Fit(Roclay.unbounded) }, named("a", Geometry2d.size(0, 0))))
	layout = named_layout("root", Roclay.box(config, [a]))
	conforms!(layout, Geometry2d.size(200, 100), [rect("root", 0, 0, 200, 100), rect("a", 0, 0, 100, 50)])
}

aspect_ratio_fill_max_width! : () => Bool
aspect_ratio_fill_max_width! = || {
	config = { ..Roclay.default_box, sizing: { width: Fixed(100), height: Fixed(50) } }
	min_10_max_30 = { min: Bounded(10), max: Bounded(30) }
	a = Roclay.aspect_ratio(3, Roclay.sized({ width: Fill(min_10_max_30), height: Fit(Roclay.unbounded) }, named("a", Geometry2d.size(0, 0))))
	layout = named_layout("root", Roclay.box(config, [a]))
	conforms!(layout, Geometry2d.size(100, 50), [rect("root", 0, 0, 100, 50), rect("a", 0, 0, 30, 10)])
}

aspect_ratio_percent_height_propagates! : () => Bool
aspect_ratio_percent_height_propagates! = || {
	aspect_config = {
		..Roclay.default_box,
		direction: TopToBottom,
		sizing: { width: Fill(Roclay.unbounded), height: Percent(0.5) },
	}
	aspect = named_layout(
		"aspect",
		Roclay.aspect_ratio(0.5, Roclay.box(aspect_config, [named("zero", Geometry2d.size(0, 0))])),
	)
	wrapper = named_layout("wrapper", Roclay.column([aspect, named("text", Geometry2d.size(1, 1))]))
	root_config = { ..Roclay.default_box, sizing: { width: Fixed(217), height: Fixed(127) } }
	layout = named_layout("root", Roclay.box(root_config, [wrapper]))
	conforms!(
		layout,
		Geometry2d.size(217, 127),
		[
			rect("root", 0, 0, 217, 127),
			rect("wrapper", 0, 0, 1, 1.5),
			rect("aspect", 0, 0, 0.375, 0.75),
			rect("zero", 0, 0, 0, 0),
			rect("text", 0, 0.75, 1, 1),
		],
	)
}

compression_queues_minimum_children! : () => Bool
compression_queues_minimum_children! = || {
	text_box = |name, size| named_layout(name, Roclay.box(Roclay.default_box, [Roclay.spacer(size)]))
	aspect_text = Roclay.aspect_ratio(4, text_box("aspect", Geometry2d.size(6, 1)))
	nested = named_layout("nested", Roclay.column([aspect_text, text_box("last", Geometry2d.size(1, 1))]))
	column = named_layout("column", Roclay.column([text_box("first", Geometry2d.size(1, 1)), nested]))
	max_1 = { min: Unbounded, max: Bounded(1) }
	clamp_config = { ..Roclay.default_box, sizing: { width: Fit(Roclay.unbounded), height: Fit(max_1) } }
	clamp = named_layout("clamp", Roclay.box(clamp_config, [column]))
	root_config = { ..Roclay.default_box, sizing: { width: Fixed(198), height: Fixed(46) } }
	layout = named_layout("root", Roclay.box(root_config, [clamp]))
	conforms!(
		layout,
		Geometry2d.size(198, 46),
		[
			rect("root", 0, 0, 198, 46),
			rect("clamp", 0, 0, 6, 1),
			rect("column", 0, 0, 6, 3),
			rect("first", 0, 0, 1, 1),
			rect("nested", 0, 1, 6, 2.0078),
			rect("aspect", 0, 1, 4.062, 1.0155),
			rect("last", 0, 2.0155, 1, 1),
		],
	)
}

nested_box_positions_children! : () => Bool
nested_box_positions_children! = || {
	inner_config = { ..Roclay.default_box, direction: TopToBottom, padding: Geometry2d.insets(5, 2, 4, 3), gap: 2 }
	inner = Roclay.box(inner_config, [named("a", Geometry2d.size(10, 5)), named("b", Geometry2d.size(20, 8))])
	root_config = { ..Roclay.default_box, sizing: { width: Fixed(120), height: Fixed(80) }, padding: Geometry2d.insets(3, 7, 5, 4), gap: 6 }
	layout = named_layout("root", Roclay.box(root_config, [inner, named("c", Geometry2d.size(15, 7))]))
	conforms!(layout, Geometry2d.size(120, 80), [rect("root", 0, 0, 120, 80), rect("a", 7, 8, 10, 5), rect("b", 7, 15, 20, 8), rect("c", 35, 3, 15, 7)])
}

overflow_cross_center! : () => Bool
overflow_cross_center! = || {
	config = { ..Roclay.default_box, sizing: { width: Fixed(10), height: Fixed(10) }, cross_align: CrossCenter }
	layout = named_layout("root", Roclay.box(config, [named("a", Geometry2d.size(5, 20))]))
	conforms!(layout, Geometry2d.size(10, 10), [rect("root", 0, 0, 10, 10), rect("a", 0, -5, 5, 20)])
}

unequal_grow_main_axis! : () => Bool
unequal_grow_main_axis! = || {
	config = { ..Roclay.default_box, direction: TopToBottom, sizing: { width: Fixed(1), height: Fixed(4) } }
	a = Roclay.sized({ width: Fit(Roclay.unbounded), height: Fill(Roclay.unbounded) }, named("a", Geometry2d.size(1, 1)))
	b = Roclay.sized({ width: Fit(Roclay.unbounded), height: Fill(Roclay.unbounded) }, named("b", Geometry2d.size(1, 2)))
	layout = named_layout("root", Roclay.box(config, [a, b]))
	conforms!(layout, Geometry2d.size(1, 4), [rect("root", 0, 0, 1, 4), rect("a", 0, 0, 1, 1.9922), rect("b", 0, 1.9922, 1, 2)])
}

clip_child_offset_places_children! : () => Bool
clip_child_offset_places_children! = || {
	clip = { horizontal: Bool.True, vertical: Bool.True, child_offset: Geometry2d.point(-3, 7) }
	config = { ..Roclay.default_box, sizing: { width: Fixed(50), height: Fixed(50) }, padding: Geometry2d.insets(6, 0, 0, 5), clip }
	layout = named_layout("root", Roclay.box(config, [named("a", Geometry2d.size(10, 10))]))
	conforms!(layout, Geometry2d.size(50, 50), [rect("root", 0, 0, 50, 50), rect("a", 2, 13, 10, 10)])
}

clip_child_offset_nested! : () => Bool
clip_child_offset_nested! = || {
	inner_config = { ..Roclay.default_box, padding: Geometry2d.insets(2, 0, 0, 3), gap: 4 }
	inner = named_layout("a", Roclay.box(inner_config, [named("b", Geometry2d.size(10, 8)), named("c", Geometry2d.size(7, 6))]))
	clip = { horizontal: Bool.True, vertical: Bool.True, child_offset: Geometry2d.point(-4, 8) }
	root_config = { ..Roclay.default_box, sizing: { width: Fixed(60), height: Fixed(50) }, padding: Geometry2d.insets(6, 0, 0, 5), clip }
	layout = named_layout("root", Roclay.box(root_config, [inner]))
	conforms!(layout, Geometry2d.size(60, 50), [rect("root", 0, 0, 60, 50), rect("a", 1, 14, 24, 10), rect("b", 4, 16, 10, 8), rect("c", 18, 16, 7, 6)])
}

controlled_container_places_kids! : () => Bool
controlled_container_places_kids! = || {
	config = { ..Roclay.default_box, sizing: { width: Fixed(50), height: Fixed(30) } }
	place_container! : Roclay.PlaceContainer(NamedRecording)
	place_container! = |placement, _info, place_kids!| {
		RoclayRecording.one({ name: "control", rect: placement.rect }) +
			place_kids!(Geometry2d.point(3, 4))
	}
	layout = named_layout("root", Roclay.container(config, place_container!, [named("a", Geometry2d.size(10, 8))]))
	conforms!(layout, Geometry2d.size(50, 30), [rect("root", 0, 0, 50, 30), rect("control", 0, 0, 50, 30), rect("a", 3, 4, 10, 8)])
}

inherited_clip_reaches_child! : () => Bool
inherited_clip_reaches_child! = || {
	layout = Roclay.row([Roclay.leaf(Geometry2d.size(10, 10), record_placement)])
	measured = Roclay.measure(layout)
	root_placement = {
		rect: Geometry2d.rect(0, 0, 10, 10),
		clip_rect: Geometry2d.rect(2, 3, 4, 5),
	}
	placed = (measured.place!)(root_placement)
	match List.get(placed.items, 0) {
		Ok(placement) => placement.rect == Geometry2d.rect(0, 0, 10, 10) and placement.clip_rect == Geometry2d.rect(2, 3, 4, 5)
		Err(_) => Bool.False
	}
}

clipping_container_bounds_child_clip! : () => Bool
clipping_container_bounds_child_clip! = || {
	clip = { horizontal: Bool.True, vertical: Bool.True, child_offset: Geometry2d.point(-5, 0) }
	config = { ..Roclay.default_box, sizing: { width: Fixed(10), height: Fixed(10) }, clip }
	layout = Roclay.box(config, [Roclay.leaf(Geometry2d.size(10, 10), record_placement)])
	measured = Roclay.measure(layout)
	placed = (measured.place!)(Geometry2d.root_placement(Geometry2d.rect(0, 0, 10, 10)))
	match List.get(placed.items, 0) {
		Ok(placement) => placement.rect == Geometry2d.rect(-5, 0, 10, 10) and placement.clip_rect == Geometry2d.rect(0, 0, 5, 10)
		Err(_) => Bool.False
	}
}

first_failure! : () => I32
first_failure! = || if !(row_gap_and_padding!()) {
	1
} else if !(column_gap_and_padding!()) {
	2
} else if !(fixed_box_centers_child!()) {
	3
} else if !(percent_child!()) {
	4
} else if !(grow_main_axis!()) {
	5
} else if !(grow_cross_axis!()) {
	6
} else if !(clamp_grow!()) {
	7
} else if !(aspect_ratio_width_drives_height!()) {
	8
} else if !(aspect_ratio_height_drives_width!()) {
	9
} else if !(aspect_ratio_percent_width!()) {
	10
} else if !(aspect_ratio_fill_max_width!()) {
	11
} else if !(aspect_ratio_percent_height_propagates!()) {
	12
} else if !(compression_queues_minimum_children!()) {
	13
} else if !(nested_box_positions_children!()) {
	14
} else if !(overflow_cross_center!()) {
	15
} else if !(unequal_grow_main_axis!()) {
	16
} else if !(clip_child_offset_places_children!()) {
	17
} else if !(clip_child_offset_nested!()) {
	18
} else if !(controlled_container_places_kids!()) {
	19
} else if !(inherited_clip_reaches_child!()) {
	20
} else if !(clipping_container_bounds_child_clip!()) {
	21
} else {
	0
}

main! = || first_failure!()
