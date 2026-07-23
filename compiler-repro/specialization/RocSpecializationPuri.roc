app [main!] {
	test_host: platform "../../test-platform/main.roc",
	roclay: "../../roclay/main.roc",
	puri: "../../puri/main.roc",
}

import roclay.Geometry2d
import puri.Puri
import roclay.Roclay

main! = || {
	layout : Roclay.Layout(Puri.Frame({}, {}))
	layout = Roclay.column_with_gap(4, [Roclay.spacer(Geometry2d.size(20, 10)), Roclay.spacer(Geometry2d.size(30, 12))])
	measured = Roclay.measure(layout)
	placement = Geometry2d.root_placement(Geometry2d.rect(0, 0, measured.size.width, measured.size.height))
	_placed = (measured.place!)(Puri.frame({}), placement)
	0
}
