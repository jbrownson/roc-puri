## Data-driven conformance runner for Clay's recursive-tree protocol.
##
## Every named Clay node becomes a decorated Roclay box. Intrinsic leaves use
## the same wrapper-plus-fixed-child shape as the oracle and Halay tests.
import geometry.Geometry2d
import roclay.Roclay

RoclayTreeConformance := [].{

	TreeNode := [
		IntrinsicNode(
			{
				config : Roclay.BoxConfig,
				aspect_ratio : [Some(Roclay.Scalar), None],
				intrinsic : Roclay.Size,
			},
		),
		TextNode(
			{
				config : Roclay.BoxConfig,
				aspect_ratio : [Some(Roclay.Scalar), None],
				text : Str,
				font_size : Roclay.Scalar,
				line_height : [Some(Roclay.Scalar), None],
				wrap_mode : Roclay.TextWrapMode,
				align : Roclay.TextAlign,
			},
		),
		ContainerNode(
			{
				config : Roclay.BoxConfig,
				aspect_ratio : [Some(Roclay.Scalar), None],
				children : List(TreeNode),
			},
		),
	]

	TreeCase : {
		root : TreeNode,
		root_size : Roclay.Size,
		expected : List(Roclay.Rect),
	}

	record : Roclay.Place(List(Roclay.Rect))
	record = |rects, placement| List.append(rects, placement.rect)

	without_recording : Roclay.Place(List(Roclay.Rect))
	without_recording = |rects, _placement| rects

	with_aspect : [Some(Roclay.Scalar), None], Roclay.Layout(List(Roclay.Rect)) -> Roclay.Layout(List(Roclay.Rect))
	with_aspect = |aspect, layout| match aspect {
		Some(ratio) => Roclay.aspect_ratio(ratio, layout)
		None => layout
	}

	layout! : TreeNode => Roclay.Layout(List(Roclay.Rect))
	layout! = |node| {
		base = match node {
			IntrinsicNode(data) => {
				fixed_child = Roclay.fixed(data.intrinsic, RoclayTreeConformance.without_recording)
				RoclayTreeConformance.with_aspect(data.aspect_ratio, Roclay.box(data.config, [fixed_child]))
			}
			TextNode(data) => {
				measure! : Roclay.MeasureText
				measure! = |string| {
					width = U64.to_f32(Str.count_utf8_bytes(string)) * data.font_size
					Geometry2d.size(width, data.font_size)
				}
				place_line! : Roclay.PlaceTextLine(List(Roclay.Rect))
				place_line! = |rects, _line_index, _line, _placement| rects
				text_layout = Roclay.text!(
					{
						line_height: data.line_height,
						wrap_mode: data.wrap_mode,
						align: data.align,
						measure!,
						place_line!,
					},
					data.text,
				)
				RoclayTreeConformance.with_aspect(data.aspect_ratio, Roclay.box(data.config, [text_layout]))
			}
			ContainerNode(data) => {
				var $children = []
				for child in data.children {
					$children = List.append($children, RoclayTreeConformance.layout!(child))
				}
				RoclayTreeConformance.with_aspect(data.aspect_ratio, Roclay.box(data.config, $children))
			}
		}
		Roclay.decorate(RoclayTreeConformance.record, base)
	}

	actual! : TreeCase => List(Roclay.Rect)
	actual! = |case| {
		measured = Roclay.measure(RoclayTreeConformance.layout!(case.root))
		placement = Geometry2d.root_placement(Geometry2d.rect(0, 0, case.root_size.width, case.root_size.height))
		(measured.place!)([], placement)
	}

	near : Roclay.Scalar, Roclay.Scalar -> Bool
	near = |expected, actual| F32.abs(expected - actual) < 0.05

	near_rect : Roclay.Rect, Roclay.Rect -> Bool
	near_rect = |expected, actual| {
		RoclayTreeConformance.near(expected.x, actual.x) and
			RoclayTreeConformance.near(expected.y, actual.y) and
				RoclayTreeConformance.near(expected.width, actual.width) and
					RoclayTreeConformance.near(expected.height, actual.height)
	}

	matches! : TreeCase => Bool
	matches! = |case| {
		actual = RoclayTreeConformance.actual!(case)
		if List.len(actual) != List.len(case.expected) {
			Bool.False
		} else {
			var $same = Bool.True
			var $index = 0
			for actual_rect in actual {
				match List.get(case.expected, $index) {
					Ok(expected_rect) => if !(RoclayTreeConformance.near_rect(expected_rect, actual_rect)) {
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
}
