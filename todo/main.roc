app [Model, program] {
	rr: platform "../roc-ray-platform/main.roc",
	geometry: "../geometry/main.roc",
	roclay: "../roclay/main.roc",
	puri: "../puri/main.roc",
	puri_roclay: "../puri-roclay/main.roc",
}

import geometry.Geometry2d
import puri.EventLoop
import puri.Frame
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
	{
		..App.default,
		title: "Puri + Roclay + RocRay",
		width: 760,
		height: 560,
		target_fps: 60,
		resizable: Bool.True,
		vsync: Bool.True,
	},
	|_host| {
		Host.disable_escape_exit!()
		Host.set_window_min_size!(520, 360)
		Ok(Todo.focus_draft(Todo.initial, LineEditing.empty_selection))
	},
)

render! : Model, Host => Try(Model, [Exit(I64), ..])
render! = |model, host| {
	events = RocRayInput.events!(host)
	build! : EventLoop.BuildFrame(TodoTheme.RenderResult, Model, RocRayInput.InputEvent)
	build! = |state, visibility| build_frame!(state, host, visibility)
	Ok(EventLoop.run!(events, model, build!))
}

build_frame! : Model, Host, EventLoop.Visibility => Frame(TodoTheme.RenderResult, Model, RocRayInput.InputEvent)
build_frame! = |model, host, visibility| {
	screen = Host.get_screen_size!()
	width = I32.to_f32(screen.width)
	height = I32.to_f32(screen.height)
	pointer_position = Geometry2d.point(host.mouse.x, host.mouse.y)
	renderer = match visibility {
		Silent => TodoTheme.silent_renderer
		Visible => TodoTheme.visible_renderer
	}
	layout = TodoUi.ui!(model, width, height, pointer_position, renderer)
	root_placement = Geometry2d.root_placement(Geometry2d.rect(0, 0, width, height))

	match visibility {
		Visible => Draw.begin_frame!()
		Silent => {}
	}
	background_result = (renderer.body_canvas.clear!)(Geometry2d.size(width, height), TodoTheme.background)
	content_frame = Roclay.place!(layout, root_placement)
	frame = Frame.from_placement_result(background_result) + content_frame
	match visibility {
		Visible => Draw.end_frame!()
		Silent => {}
	}
	frame
}
