app [main!] {
	test_host: platform "../../test-platform/main.roc",
	geometry: "../../geometry/main.roc",
	roclay: "../../roclay/main.roc",
}

import geometry.Geometry2d
import roclay.Roclay

Output := {}.{
	default : () -> Output
	default = || {}

	plus : Output, Output -> Output
	plus = |_earlier, _later| {}
}

main! = || {
	layout : Roclay.Layout(Output)
	layout = Roclay.column_with_gap(4, [Roclay.spacer(Geometry2d.size(20, 10)), Roclay.spacer(Geometry2d.size(30, 12))])
	measured = Roclay.measure(layout)
	placement = Geometry2d.root_placement(Geometry2d.rect(0, 0, measured.size.width, measured.size.height))
	_placed = (measured.place!)(placement)
	0
}
