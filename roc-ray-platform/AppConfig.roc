## Internal owner for RocRay 0.9's validated startup configuration and host
## transport. App exposes the application-facing aliases; this module remains
## private to the platform facade.
AppFramePacing := [VSync, Capped(I32), Uncapped].{
	is_eq : _
}

AppCursorMode := [CursorVisible, CursorHidden].{
	is_eq : _
}

AppConfigData : {
	title : Str,
	width : I32,
	height : I32,
	frame_pacing : AppFramePacing,
	resizable : Bool,
	fullscreen : Bool,
	cursor : AppCursorMode,
}

AppHostConfig : {
	title : Str,
	width : I32,
	height : I32,
	target_fps : I32,
	resizable : Bool,
	fullscreen : Bool,
	vsync : Bool,
	cursor_visible : Bool,
}

AppConfig := [].{

	FramePacing : AppFramePacing
	CursorMode : AppCursorMode

	Config :: {
		title : Str,
		width : I32,
		height : I32,
		frame_pacing : AppFramePacing,
		resizable : Bool,
		fullscreen : Bool,
		cursor : AppCursorMode,
	}.{
		with_title : Config, Str -> Config
		with_title = |config, title| { ..config, title }

		with_size : Config, { width : I32, height : I32 } -> Config
		with_size = |config, size| {
			..config,
			width: normalize_dimension(size.width, default_width),
			height: normalize_dimension(size.height, default_height),
		}

		with_frame_pacing : Config, FramePacing -> Config
		with_frame_pacing = |config, frame_pacing| { ..config, frame_pacing: normalize_pacing(frame_pacing) }

		with_cursor : Config, CursorMode -> Config
		with_cursor = |config, cursor| { ..config, cursor }

		with_resizable : Config, Bool -> Config
		with_resizable = |config, resizable| { ..config, resizable }

		with_fullscreen : Config, Bool -> Config
		with_fullscreen = |config, fullscreen| { ..config, fullscreen }

		frame_pacing : Config -> FramePacing
		frame_pacing = |config| config.frame_pacing

		cursor : Config -> CursorMode
		cursor = |config| config.cursor
	}

	default : Config
	default = app_default_data

	HostConfig : AppHostConfig

	to_host : {}, Config -> HostConfig
	to_host = |_, config| {
		pacing = host_pacing(config.frame_pacing)
		{
			title: config.title,
			width: config.width,
			height: config.height,
			target_fps: pacing.target_fps,
			resizable: config.resizable,
			fullscreen: config.fullscreen,
			vsync: pacing.vsync,
			cursor_visible: config.cursor == CursorVisible,
		}
	}
}

default_width : I32
default_width = 800

default_height : I32
default_height = 600

app_default_data : AppConfigData
app_default_data = {
	title: "Roc + Raylib",
	width: default_width,
	height: default_height,
	frame_pacing: Capped(240),
	resizable: Bool.False,
	fullscreen: Bool.False,
	cursor: CursorVisible,
}

normalize_pacing : AppFramePacing -> AppFramePacing
normalize_pacing = |value| match value {
	Capped(fps) => if fps <= 0 Uncapped else value
	_ => value
}

normalize_dimension : I32, I32 -> I32
normalize_dimension = |value, fallback| if value > 0 value else fallback

host_pacing : AppFramePacing -> { target_fps : I32, vsync : Bool }
host_pacing = |value| match value {
	VSync => { target_fps: 0, vsync: Bool.True }
	Capped(fps) => { target_fps: fps, vsync: Bool.False }
	Uncapped => { target_fps: 0, vsync: Bool.False }
}

expect AppConfig.to_host({}, AppConfig.default.with_frame_pacing(Capped(60))).target_fps == 60
expect AppConfig.to_host({}, AppConfig.default.with_frame_pacing(VSync)).vsync
