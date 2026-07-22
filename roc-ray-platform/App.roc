import Host

AppConfig : {
	title : Str,
	width : I32,
	height : I32,
	target_fps : I32,
	resizable : Bool,
	fullscreen : Bool,
	vsync : Bool,
	cursor_visible : Bool,
}

App := [].{
	Config : AppConfig

	InitCallback(model, errors) : Host => Try(model, [Exit(I64), ..errors])

	Init(model, errors) : {
		config : Config,
		run! : InitCallback(model, errors),
	}

	default : Config
	default = {
		title: "Roc + Raylib",
		width: 800,
		height: 600,
		target_fps: 60,
		resizable: Bool.False,
		fullscreen: Bool.False,
		vsync: Bool.False,
		cursor_visible: Bool.True,
	}

	init : Config, InitCallback(model, errors) -> Init(model, errors)
	init = |config, run!| { config, run! }
}
