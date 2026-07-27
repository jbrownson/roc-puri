app [main!] {
	test_host: platform "./platform/main.roc",
	geometry: "../../geometry/main.roc",
	roclay: "../../roclay/main.roc",
	puri: "../../puri/main.roc",
	puri_roclay: "../main.roc",
	recording: "./support/main.roc",
}

import geometry.Geometry2d
import puri.Frame
import puri.Canvas
import recording.CanvasRecording
import puri_roclay.Layout
import roclay.Roclay

canvas : Canvas.Operations(CanvasRecording.Recording(Str), Str)
canvas = CanvasRecording.canvas

leaf_preserves_widget_constraints! : () => Bool
leaf_preserves_widget_constraints! = || {
	preferred_size = Geometry2d.size(60, 13)
	minimum_size = Geometry2d.size(17, 13)
	widget! = |placement| Frame.from_placement_result((canvas.fill_rect!)(placement.rect, "widget"))
	flexible = Roclay.sized(
		{ width: Fill(Roclay.unbounded), height: Fit(Roclay.unbounded) },
		Layout.leaf(preferred_size, minimum_size, widget!),
	)
	fixed = Roclay.fixed(
		Geometry2d.size(10, 13),
		|placement| Frame.from_placement_result((canvas.fill_rect!)(placement.rect, "fixed")),
	)
	config = {
		..Roclay.default_box,
		gap: 2,
		sizing: { width: Fixed(50), height: Fit(Roclay.unbounded) },
	}
	measured = Roclay.measure(Roclay.box(config, [flexible, fixed]))
	frame = (measured.place!)(Geometry2d.root_placement(Geometry2d.rect(0, 0, measured.size.width, measured.size.height)))
	widget_matches = match List.get(frame.placement_result.commands, 0) {
		Ok(FillRect(data)) => data.paint == "widget" and data.rect == Geometry2d.rect(0, 0, 38, 13)
		_ => Bool.False
	}
	fixed_matches = match List.get(frame.placement_result.commands, 1) {
		Ok(FillRect(data)) => data.paint == "fixed" and data.rect == Geometry2d.rect(40, 0, 10, 13)
		_ => Bool.False
	}
	List.len(frame.placement_result.commands) == 2 and widget_matches and fixed_matches
}

main! = || if leaf_preserves_widget_constraints!() 0 else 1
