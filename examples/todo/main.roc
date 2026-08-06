app [Model, program] {
	rr: platform "../roc-ray-platform/main.roc",
	geometry: "https://github.com/jbrownson/roc-puri-geometry/releases/download/0.1.0/8YcrEeY7J3K9khuA2ULAcMZvzAbqPzdT9qKCDX9YvqSP.tar.zst",
	roclay: "https://github.com/jbrownson/roc-roclay/releases/download/0.1.0/5f3c1Nmg2L7nsKAR6ojUWPngsUSrjdLaWsrkBSLdQQb8.tar.zst",
	puri: "https://github.com/jbrownson/roc-puri/releases/download/0.1.0/F873LAc2K6L83q6r8qxusFbEBxsapZWDXfqHm778fT5H.tar.zst",
	puri_roclay: "https://github.com/jbrownson/roc-puri-roclay/releases/download/0.1.0/3tD9YVvq9MXBZ4djoPtFCrDPLFPfG3VVGwiDGQWzgW6f.tar.zst",
}

import geometry.Geometry2d
import puri.EventLoop
import puri.Frame
import RocRayCanvas
import RocRayInput
import puri.LineEditing
import Todo
import TodoTheme
import TodoUi
import roclay.Roclay
import rr.App
import rr.Draw
import rr.Host

Model : Todo.Model

program = { init!, render! }

init! : App.Init(Model, [])
init! = App.init(
	App.default
		.with_title("Puri + Roclay + RocRay")
		.with_size({ width: 760, height: 560 })
		.with_resizable(Bool.True)
		.with_frame_pacing(Capped(60)),
	|_host| {
		Host.disable_escape_exit!()
		Host.set_window_min_size!(520, 360)
		Ok(Todo.focus_draft(Todo.initial, LineEditing.empty_selection))
	},
)

render! : Model, Host, Draw.Frame => Try(Model, [Exit(I64), ..])
render! = |model, host, draw_frame| {
	input = RocRayInput.events(host, model.click_series)
	model_with_click_series = Todo.set_click_series(model, input.click_series)
	build! : EventLoop.BuildFrame(TodoTheme.RenderResult, Model, [])
	build! = |state, visibility| build_frame!(state, host, draw_frame, visibility)
	Ok(EventLoop.run!(input.events, host.timestamp_nanos, model_with_click_series, build!))
}

build_frame! : Model, Host, Draw.Frame, EventLoop.Visibility => Frame(TodoTheme.RenderResult, Model, RocRayInput.InputEvent)
build_frame! = |model, host, draw_frame, visibility| {
	width = I32.to_f32(host.screen.width)
	height = I32.to_f32(host.screen.height)
	pointer_position = Geometry2d.point(host.mouse.x, host.mouse.y)
	renderer = match visibility {
		Silent => TodoTheme.silent_renderer
		Visible => TodoTheme.visible_renderer(draw_frame)
	}
	with_clip! = match visibility {
		Silent => |_rect, draw!| draw!()
		Visible => |rect, draw!| RocRayCanvas.with_clip!(draw_frame, rect, draw!)
	}
	layout = TodoUi.ui!(model, width, height, pointer_position, renderer, with_clip!)
	root_placement = Geometry2d.root_placement(Geometry2d.rect(0, 0, width, height))

	background_result = (renderer.body_canvas.clear!)(Geometry2d.size(width, height), TodoTheme.background)
	content_frame = Roclay.place!(layout, root_placement)
	frame = Frame.from_placement_result(background_result) + content_frame
	frame
}
