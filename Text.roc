## Renderer- and layout-independent single-line text rendering and width
## fitting. Font selection remains a property of the supplied canvas and
## measurement function.
import geometry.Geometry2d
import Frame
import Canvas
import Geometry
import TextMeasurement
import Utf8

Text := [].{

	Measure : TextMeasurement.Measure

	Description(paint) : {
		text : Str,
		paint : paint,
	}

	fit_with_ellipsis! : Measure, Str, Geometry.Scalar => Str
	fit_with_ellipsis! = |measure!, string, available_width| {
		if (measure!(string)).width <= available_width {
			string
		} else {
			suffix = "..."
			suffix_width = (measure!(suffix)).width
			if suffix_width > available_width {
				""
			} else {
				bytes = Str.to_utf8(string)
				var $prefix_bytes = []
				var $best = ""
				var $index = 0
				for byte in bytes {
					$prefix_bytes = List.append($prefix_bytes, byte)
					next_index = $index + 1
					complete = if next_index >= List.len(bytes) {
						Bool.True
					} else match List.get(bytes, next_index) {
						Ok(next) => !(Utf8.is_continuation_byte(next))
						Err(_) => Bool.True
					}
					if complete {
						match Str.from_utf8($prefix_bytes) {
							Ok(prefix) => if (measure!(prefix)).width + suffix_width <= available_width {
								$best = prefix
							}
							Err(_) => {}
						}
					}
					$index = next_index
				}
				Str.concat($best, suffix)
			}
		}
	}

	size : TextMeasurement.Metrics -> Geometry.Size
	size = |metrics| Geometry2d.size(metrics.width, metrics.font_ascent + metrics.font_descent)

	widget : Canvas.Operations(result, paint), TextMeasurement.Metrics, Description(paint) -> Frame.Widget(result, state, event)
	widget = |canvas, metrics, description| {
		|placement| {
			baseline = Geometry2d.point(placement.rect.x, placement.rect.y + metrics.font_ascent)
			Frame.from_placement_result((canvas.fill_text!)(baseline, description.paint, description.text))
		}
	}
}
