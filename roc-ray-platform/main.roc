## Narrow RocRay 0.8 facade for Puri's native example.
##
## The prebuilt host is upstream RocRay; this platform exposes only the modules
## and hosted effects Puri currently uses. Keeping the surface small avoids
## coupling Puri to RocRay's game/asset APIs and gives clipping/text input an
## obvious extension point.
platform ""
	requires {
		[Model : model] for program : {
			init! : {
				config : App.Config,
				run! : Host => Try(model, [Exit(I64), ..]),
			},
			render! : model, Host => Try(model, [Exit(I64), ..]),
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
		"roc_draw_begin_frame": Draw.begin_frame!,
		"roc_draw_clear": Draw.clear!,
		"roc_draw_end_frame": Draw.end_frame!,
		"roc_draw_line_raw": Draw.line_raw!,
		"roc_draw_measure_text_raw": Draw.measure_text_raw!,
		"roc_draw_rectangle_lines_raw": Draw.rectangle_lines_raw!,
		"roc_draw_rectangle_raw": Draw.rectangle_raw!,
		"roc_draw_text_raw": Draw.text_raw!,
		"roc_draw_begin_scissor_raw": Draw.begin_scissor_raw!,
		"roc_draw_end_scissor": Draw.end_scissor!,
		"roc_host_get_screen_size": Host.get_screen_size!,
		"roc_host_disable_escape_exit": Host.disable_escape_exit!,
		"roc_host_set_window_min_size": Host.set_window_min_size!,
		"roc_clipboard_get_text": Clipboard.get_text!,
		"roc_clipboard_set_text": Clipboard.set_text!,
		"roc_mouse_click_count": Mouse.click_count!,
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
import Host
import Keys
import Mouse

HostStateFromHost : {
	frame_count : U64,
	timestamp_nanos : U64,
	frame_time : F32,
	keys : List(U8),
	keys_pressed : List(U8),
	keys_released : List(U8),
	mouse : {
		buttons : List(U8),
		buttons_pressed : List(U8),
		buttons_released : List(U8),
		wheel : F32,
		x : F32,
		y : F32,
		left : Bool,
		middle : Bool,
		right : Bool,
	},
}

host_from_state : HostStateFromHost -> Host
host_from_state = |state| {
	frame_count: state.frame_count,
	timestamp_nanos: state.timestamp_nanos,
	frame_time: state.frame_time,
	keys: state.keys,
	keys_pressed: state.keys_pressed,
	keys_released: state.keys_released,
	mouse: state.mouse,
}

app_config_for_host! : () => App.Config
app_config_for_host! = || program.init!.config

init_for_host! : HostStateFromHost => Try(Box(Model), I64)
init_for_host! = |host_state| match (program.init!.run!)(host_from_state(host_state)) {
	Ok(model) => Ok(Box.box(model))
	Err(Exit(code)) => Err(code)
	Err(_) => Err(-1)
}

render_for_host! : Box(Model), HostStateFromHost => Try(Box(Model), I64)
render_for_host! = |boxed_model, host_state| match (program.render!)(Box.unbox(boxed_model), host_from_state(host_state)) {
	Ok(model) => Ok(Box.box(model))
	Err(Exit(code)) => Err(code)
	Err(_) => Err(-1)
}

drop_model_for_host! : Box(Model) => {}
drop_model_for_host! = |_boxed_model| {}
