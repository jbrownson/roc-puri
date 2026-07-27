app [Model, program] {
	rr: platform "../roc-ray-platform/main.roc",
	geometry: "../geometry/main.roc",
	roclay: "../roclay/main.roc",
	puri: "../puri/main.roc",
	puri_roclay: "../puri-roclay/main.roc",
}

import geometry.Geometry2d
import puri.Puri
import PuriInputRocRay
import puri.PuriLineEdit
import Todo
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
		Ok(Todo.focus_draft(Todo.initial, PuriLineEdit.empty_selection))
	},
)

render! : Model, Host => Try(Model, [Exit(I64), ..])
render! = |model, host| {
	screen = Host.get_screen_size!()
	width = I32.to_f32(screen.width)
	height = I32.to_f32(screen.height)
	pointer_position = Geometry2d.point(host.mouse.x, host.mouse.y)
	layout = TodoUi.ui!(model, width, height, pointer_position)
	measured = Roclay.measure(layout)
	placement = Geometry2d.root_placement(Geometry2d.rect(0, 0, width, height))

	Draw.begin_frame!()
	Draw.clear!(TodoUi.background)
	frame = (measured.place!)(placement)
	Draw.end_frame!()

	Ok(PuriInputRocRay.dispatch!(frame.handler, model, host, Todo.clear_focus))
}
