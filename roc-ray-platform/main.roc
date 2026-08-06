## Narrow RocRay 0.9 facade for Puri's native example.
##
## The prebuilt host is upstream RocRay; this platform exposes only the modules
## and hosted effects Puri currently uses. Keeping the surface small avoids
## coupling Puri to RocRay's game, asset, and audio APIs.
platform ""
	requires {
		[Model : model] for program : {
			init! : {
				config : App.Config,
				run! : Host => Try(model, [Exit(I64), ..]),
			},
			render! : model, Host, Draw.Frame => Try(model, [Exit(I64), ..]),
		}
	}
	exposes [Draw, Color, Host, Keys, Mouse, Clipboard, App]
	packages {}
	provides {
		"app_config_for_host": app_config_for_host!,
		"init_for_host": init_for_host!,
		"render_for_host": render_for_host!,
		"drop_model_for_host": drop_model_for_host!,
	}
	hosted {
		"roc_draw_clear": DrawHost.clear!,
		"roc_draw_line_raw": DrawHost.line!,
		"roc_draw_measure_text_raw": DrawHost.measure_text!,
		"roc_draw_rectangle_lines_raw": DrawHost.rectangle_lines!,
		"roc_draw_rectangle_raw": DrawHost.rectangle!,
		"roc_draw_text_raw": DrawHost.text!,
		"roc_draw_begin_scissor_raw": DrawHost.begin_scissor!,
		"roc_draw_end_scissor_raw": DrawHost.end_scissor!,
		"roc_host_disable_escape_exit": Host.disable_escape_exit!,
		"roc_host_set_window_min_size": Host.set_window_min_size!,
		"roc_clipboard_get_text": Clipboard.get_text!,
		"roc_clipboard_set_text": Clipboard.set_text!,
	}
	targets: {
		inputs_dir: "targets/",
		x64mac: { inputs: ["libhost.a", "puri_roc_ray_adapter.o", "libraylib.a", app] },
		arm64mac: { inputs: ["libhost.a", "puri_roc_ray_adapter.o", "libraylib.a", app] },
	}

import App
import Clipboard
import Color
import Draw
import DrawHost
import Host
import Keys
import Mouse
import AppConfig

HostStateFromHost : {
	frame_count : U64,
	timestamp_nanos : U64,
	frame_time : F32,
	screen : { width : I32, height : I32 },
	keys : List(U8),
	text_input : List(U32),
	gamepads : {
		available : List(U8),
		buttons : List(U8),
		axes : List(F32),
	},
	mouse : {
		buttons : List(U8),
		left : Bool,
		middle : Bool,
		right : Bool,
		wheel : F32,
		wheel_x : F32,
		wheel_y : F32,
		delta_x : F32,
		delta_y : F32,
		x : F32,
		y : F32,
	},
}

host_from_state : HostStateFromHost -> Host
host_from_state = |state| {
	frame_count: state.frame_count,
	timestamp_nanos: state.timestamp_nanos,
	frame_time: state.frame_time,
	screen: state.screen,
	keys: state.keys,
	text_input: state.text_input,
	gamepads: {
		connected: state.gamepads.available,
		buttons: state.gamepads.buttons,
		axes: state.gamepads.axes,
	},
	mouse: state.mouse,
}

app_config_for_host! : () => AppConfig.HostConfig
app_config_for_host! = || AppConfig.to_host({}, program.init!.config)

init_for_host! : HostStateFromHost => Try(Box(Model), I64)
init_for_host! = |host_state| match (program.init!.run!)(host_from_state(host_state)) {
	Ok(model) => Ok(Box.box(model))
	Err(Exit(code)) => Err(code)
	Err(_) => Err(-1)
}

render_for_host! : Box(Model), HostStateFromHost => Try(Box(Model), I64)
render_for_host! = |boxed_model, host_state| {
	frame = Draw.Frame.from_host(DrawHost.Frame.for_host)
	match (program.render!)(Box.unbox(boxed_model), host_from_state(host_state), frame) {
		Ok(model) => Ok(Box.box(model))
		Err(Exit(code)) => Err(code)
		Err(_) => Err(-1)
	}
}

drop_model_for_host! : Box(Model) => {}
drop_model_for_host! = |_boxed_model| {}
