## Package-private mapping between UTF-8 caret indices and measured x positions.
import Geometry
import TextMeasurement
import Utf8

CaretMap := [].{

	Position : {
		index : U64,
		x : Geometry.Scalar,
	}

	measure_from! : TextMeasurement.Measure, Str, U64, List(Position) => List(Position)
	measure_from! = |measure!, string, index, positions| {
		metrics = measure!(Utf8.prefix(string, index))
		next_positions = List.append(positions, { index, x: metrics.width })
		bytes = Str.to_utf8(string)
		if index >= List.len(bytes) {
			next_positions
		} else {
			next = Utf8.next_boundary(bytes, index)
			CaretMap.measure_from!(measure!, string, next, next_positions)
		}
	}

	measure! : TextMeasurement.Measure, Str => List(Position)
	measure! = |measure!, string| CaretMap.measure_from!(measure!, string, 0, [])

	closest_index : List(Position), Geometry.Scalar -> U64
	closest_index = |positions, target| {
		var $best_index = 0
		var $best_distance = F32.infinity
		for position in positions {
			distance = F32.abs(position.x - target)
			if distance < $best_distance {
				$best_distance = distance
				$best_index = position.index
			}
		}
		$best_index
	}

	x_at : List(Position), U64 -> Geometry.Scalar
	x_at = |positions, requested| {
		var $x = 0
		for position in positions {
			if position.index == requested {
				$x = position.x
			}
		}
		$x
	}
}
