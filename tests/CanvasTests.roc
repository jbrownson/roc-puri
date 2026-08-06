app [main!] {
	test_host: platform "./platform/main.roc",
	geometry: "https://github.com/jbrownson/roc-puri-geometry/releases/download/0.1.0/8YcrEeY7J3K9khuA2ULAcMZvzAbqPzdT9qKCDX9YvqSP.tar.zst",
	puri: "../package/main.roc",
	recording: "./support/main.roc",
}

import geometry.Geometry2d
import puri.Canvas
import recording.CanvasRecording

records_nested_clip! : () => Bool
records_nested_clip! = || {
	canvas : Canvas.Operations(CanvasRecording.Recording(Str), Str)
	canvas = CanvasRecording.canvas
	first = (canvas.fill_rect!)(Geometry2d.rect(0, 0, 20, 10), "background")
	clipped = (canvas.with_clip!)(
		Geometry2d.rect(2, 2, 10, 6),
		|| {
			(canvas.fill_text!)(Geometry2d.point(3, 8), "foreground", "abc") +
				(canvas.stroke_line!)(Geometry2d.point(2, 2), Geometry2d.point(12, 8), "line", 1.5)
		},
	)
	final = first + clipped
	first_matches = match List.get(final.commands, 0) {
		Ok(FillRect(data)) => data.rect == Geometry2d.rect(0, 0, 20, 10) and data.paint == "background"
		_ => Bool.False
	}
	clip_matches = match List.get(final.commands, 1) {
		Ok(Clip(data)) => {
			text_matches = match List.get(data.children, 0) {
				Ok(FillText(text)) => text.at == Geometry2d.point(3, 8) and text.paint == "foreground" and text.text == "abc"
				_ => Bool.False
			}
			line_matches = match List.get(data.children, 1) {
				Ok(StrokeLine(line)) => line.start == Geometry2d.point(2, 2) and line.end == Geometry2d.point(12, 8) and line.paint == "line" and line.width == 1.5
				_ => Bool.False
			}
			data.rect == Geometry2d.rect(2, 2, 10, 6) and List.len(data.children) == 2 and text_matches and line_matches
		}
		_ => Bool.False
	}
	List.len(final.commands) == 2 and first_matches and clip_matches
}

silent_canvas_ignores_draws_but_runs_scopes! : () => Bool
silent_canvas_ignores_draws_but_runs_scopes! = || {
	canvas : Canvas.Operations(CanvasRecording.Recording(Str), Str)
	canvas = Canvas.silent()
	ignored = (canvas.fill_rect!)(Geometry2d.rect(0, 0, 20, 10), "ignored")
	marker = { commands: [Clear({ size: Geometry2d.size(1, 1), paint: "scope-ran" })] }
	scoped = (canvas.with_clip!)(Geometry2d.rect(0, 0, 1, 1), || marker)
	scope_ran = match List.get(scoped.commands, 0) {
		Ok(Clear(data)) => data.paint == "scope-ran"
		_ => Bool.False
	}
	List.is_empty(ignored.commands) and List.len(scoped.commands) == 1 and scope_ran
}

main! = || if records_nested_clip!() and silent_canvas_ignores_draws_but_runs_scopes!() 0 else 1
