## Data-driven conformance runner for Clay's text protocol.
##
## The production API invokes line continuations directly. This test adapter is
## deliberately initial: it records those final line placements for comparison.
import geometry.Geometry2d
import roclay.Roclay
import RoclayRecording

RoclayTextConformance := [].{

	TextCase : {
		root_size : Roclay.Size,
		text : Str,
		font_size : Roclay.Scalar,
		line_height : [Some(Roclay.Scalar), None],
		wrap_mode : Roclay.TextWrapMode,
		align : Roclay.TextAlign,
		expected : List(Roclay.Rect),
	}

	Recording : RoclayRecording.Recording(Roclay.Rect)

	record : Roclay.Place(Recording)
	record = |placement| RoclayRecording.one(placement.rect)

	actual! : TextCase => List(Roclay.Rect)
	actual! = |case| {
		measure! : Roclay.MeasureText
		measure! = |string| {
			width = U64.to_f32(Str.count_utf8_bytes(string)) * case.font_size
			Geometry2d.size(width, case.font_size)
		}
		place_line! : Roclay.PlaceTextLine(Recording)
		place_line! = |_line_index, _line, placement| RoclayRecording.one(placement.rect)
		text_config = {
			line_height: case.line_height,
			wrap_mode: case.wrap_mode,
			align: case.align,
			measure!,
			place_line!,
		}
		text_layout = Roclay.text!(text_config, case.text)
		root_config = {
			..Roclay.default_box,
			sizing: { width: Fixed(case.root_size.width), height: Fixed(case.root_size.height) },
		}
		root = Roclay.decorate(RoclayTextConformance.record, Roclay.box(root_config, [text_layout]))
		measured = Roclay.measure(root)
		placement = Geometry2d.root_placement(Geometry2d.rect(0, 0, case.root_size.width, case.root_size.height))
		((measured.place!)(placement)).items
	}

	near : Roclay.Scalar, Roclay.Scalar -> Bool
	near = |expected, actual| F32.abs(expected - actual) < 0.05

	near_rect : Roclay.Rect, Roclay.Rect -> Bool
	near_rect = |expected, actual| {
		RoclayTextConformance.near(expected.x, actual.x) and
			RoclayTextConformance.near(expected.y, actual.y) and
				RoclayTextConformance.near(expected.width, actual.width) and
					RoclayTextConformance.near(expected.height, actual.height)
	}

	matches! : TextCase => Bool
	matches! = |case| {
		actual = RoclayTextConformance.actual!(case)
		if List.len(actual) != List.len(case.expected) {
			Bool.False
		} else {
			var $same = Bool.True
			var $index = 0
			for actual_rect in actual {
				match List.get(case.expected, $index) {
					Ok(expected_rect) => if !(RoclayTextConformance.near_rect(expected_rect, actual_rect)) {
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
