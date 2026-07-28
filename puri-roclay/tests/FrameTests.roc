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
import puri_roclay.Frame as RoclayFrame
import roclay.Roclay

canvas : Canvas.Operations(CanvasRecording.Recording(Str), Str)
canvas = CanvasRecording.canvas

child! : Roclay.Layout(Frame(CanvasRecording.Recording(Str), {}, event))
child! = Roclay.leaf(
	Geometry2d.size(20, 10),
	|placement| Frame.from_placement_result((canvas.fill_rect!)(placement.rect, "child")),
)

place! : RoclayFrame.Description(Str) => Frame(CanvasRecording.Recording(Str), {}, event)
place! = |style| {
	measured = Roclay.measure(RoclayFrame.framed!(canvas, style, child!))
	(measured.place!)(Geometry2d.root_placement(Geometry2d.rect(10, 20, measured.size.width, measured.size.height)))
}

frame_draws_around_inset_child! : () => Bool
frame_draws_around_inset_child! = || {
	style = {
		padding: Geometry2d.insets(2, 3, 4, 5),
		decoration: {
			insets: Geometry2d.insets(1, 2, 3, 4),
			background: Some("background"),
			border_paint: "border",
			border_width: 1.5,
		},
	}
	frame = place!(style)
	commands = frame.placement_result.commands
	background_matches = match List.get(commands, 0) {
		Ok(FillRect(data)) => data.rect == Geometry2d.rect(14, 21, 22, 12) and data.paint == "background"
		_ => Bool.False
	}
	child_matches = match List.get(commands, 1) {
		Ok(FillRect(data)) => data.rect == Geometry2d.rect(15, 22, 20, 10) and data.paint == "child"
		_ => Bool.False
	}
	border_matches = match List.get(commands, 2) {
		Ok(StrokeRect(data)) => data.rect == Geometry2d.rect(14, 21, 22, 12) and data.paint == "border" and data.width == 1.5
		_ => Bool.False
	}
	List.len(commands) == 3 and background_matches and border_matches and child_matches
}

frame_can_omit_background! : () => Bool
frame_can_omit_background! = || {
	style = {
		padding: Geometry2d.insets(0, 0, 0, 0),
		decoration: {
			insets: Geometry2d.insets(0, 0, 0, 0),
			background: None,
			border_paint: "border",
			border_width: 2,
		},
	}
	commands = (place!(style)).placement_result.commands
	child_matches = match List.get(commands, 0) {
		Ok(FillRect(data)) => data.paint == "child"
		_ => Bool.False
	}
	border_matches = match List.get(commands, 1) {
		Ok(StrokeRect(data)) => data.paint == "border" and data.width == 2
		_ => Bool.False
	}
	List.len(commands) == 2 and border_matches and child_matches
}

direct_decoration_surrounds_leaf! : () => Bool
direct_decoration_surrounds_leaf! = || {
	decoration = {
		insets: Geometry2d.insets(0, 0, 0, 0),
		background: Some("background"),
		border_paint: "border",
		border_width: 1,
	}
	measured = Roclay.measure(RoclayFrame.decorate!(canvas, decoration, child!))
	placement = Geometry2d.root_placement(Geometry2d.rect(10, 20, measured.size.width, measured.size.height))
	commands = ((measured.place!)(placement)).placement_result.commands
	first_is_background = match List.get(commands, 0) {
		Ok(FillRect(_)) => Bool.True
		_ => Bool.False
	}
	middle_is_child = match List.get(commands, 1) {
		Ok(FillRect(data)) => data.paint == "child"
		_ => Bool.False
	}
	last_is_border = match List.get(commands, 2) {
		Ok(StrokeRect(_)) => Bool.True
		_ => Bool.False
	}
	List.len(commands) == 3 and first_is_background and middle_is_child and last_is_border
}

main! = || if frame_draws_around_inset_child!() and frame_can_omit_background!() and direct_decoration_surrounds_leaf!() 0 else 1
