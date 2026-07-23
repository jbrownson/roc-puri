app [main!] {
	test_host: platform "../../test-platform/main.roc",
	roclay: "../../roclay/main.roc",
	puri: "../../puri/main.roc",
}

import roclay.Geometry2d
import puri.Puri
import puri.PuriCanvas
import puri.PuriCanvasRecording
import puri.PuriFrame
import roclay.Roclay

metrics : Str -> PuriCanvas.TextMetrics
metrics = |_string| {
	width: 0,
	actual_ascent: 0,
	actual_descent: 0,
	font_ascent: 0,
	font_descent: 0,
}

canvas : PuriCanvas.Canvas(PuriCanvasRecording.Recording(Str), Str)
canvas = PuriCanvasRecording.canvas(metrics)

child! : Roclay.Layout(Puri.Frame(PuriCanvasRecording.Recording(Str), {}))
child! = Roclay.leaf(
	Geometry2d.size(20, 10),
	|frame, placement| {
		render = PuriCanvas.fill_rect!(canvas, frame.render, placement.rect, "child")
		Puri.with_render(render, frame)
	},
)

place! : PuriFrame.Frame(Str) => Puri.Frame(PuriCanvasRecording.Recording(Str), {})
place! = |style| {
	measured = Roclay.measure(PuriFrame.framed!(canvas, style, child!))
	(measured.place!)(Puri.frame(PuriCanvasRecording.empty), Geometry2d.root_placement(Geometry2d.rect(10, 20, measured.size.width, measured.size.height)))
}

frame_draws_before_inset_child! : () => Bool
frame_draws_before_inset_child! = || {
	style = {
		padding: Geometry2d.insets(2, 3, 4, 5),
		insets: Geometry2d.insets(1, 2, 3, 4),
		background: Some("background"),
		border_paint: "border",
		border_width: 1.5,
	}
	result = place!(style)
	commands = result.render.commands
	background_matches = match List.get(commands, 0) {
		Ok(FillRect(data)) => data.rect == Geometry2d.rect(14, 21, 22, 12) and data.paint == "background"
		_ => Bool.False
	}
	border_matches = match List.get(commands, 1) {
		Ok(StrokeRect(data)) => data.rect == Geometry2d.rect(14, 21, 22, 12) and data.paint == "border" and data.width == 1.5
		_ => Bool.False
	}
	child_matches = match List.get(commands, 2) {
		Ok(FillRect(data)) => data.rect == Geometry2d.rect(15, 22, 20, 10) and data.paint == "child"
		_ => Bool.False
	}
	List.len(commands) == 3 and background_matches and border_matches and child_matches
}

frame_can_omit_background! : () => Bool
frame_can_omit_background! = || {
	style = {
		padding: Geometry2d.insets(0, 0, 0, 0),
		insets: Geometry2d.insets(0, 0, 0, 0),
		background: None,
		border_paint: "border",
		border_width: 2,
	}
	commands = (place!(style)).render.commands
	border_matches = match List.get(commands, 0) {
		Ok(StrokeRect(data)) => data.paint == "border" and data.width == 2
		_ => Bool.False
	}
	child_matches = match List.get(commands, 1) {
		Ok(FillRect(data)) => data.paint == "child"
		_ => Bool.False
	}
	List.len(commands) == 2 and border_matches and child_matches
}

main! = || if frame_draws_before_inset_child!() and frame_can_omit_background!() 0 else 1
