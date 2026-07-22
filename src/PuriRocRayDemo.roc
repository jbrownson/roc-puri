app [Model, program] { rr: platform "../roc-ray-platform/main.roc" }

import Geometry2d
import Puri
import PuriCanvas
import PuriCanvasRocRay
import PuriHandler
import PuriLineEdit
import PuriLineEditWidget
import Roclay
import rr.App
import rr.Color
import rr.Draw
import rr.Host
import rr.Keys
import rr.Mouse

Model : {
	draft : Str,
	selection : [Some(PuriLineEdit.LineEditSelection), None],
	items : List(Str),
}

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
	|_host| Ok({ draft: "", selection: None, items: [] }),
)

body_text : PuriCanvasRocRay.TextStyle
body_text = PuriCanvasRocRay.default_text_style

small_text : PuriCanvasRocRay.TextStyle
small_text = { ..PuriCanvasRocRay.default_text_style, size: 19 }

title_text : PuriCanvasRocRay.TextStyle
title_text = { ..PuriCanvasRocRay.default_text_style, size: 34 }

body_canvas : PuriCanvas.Canvas(PuriCanvasRocRay.Render, Color)
body_canvas = PuriCanvasRocRay.canvas(body_text)

measure_body! : PuriLineEditWidget.Measure
measure_body! = |string| PuriCanvasRocRay.measure!(body_text, string)

background : Color
background = Color.from_hex_rgb(0xf4f1ea)

ink : Color
ink = Color.from_hex_rgb(0x272522)

muted_ink : Color
muted_ink = Color.from_hex_rgb(0x706b63)

field_background : Color
field_background = Color.white

field_border : Color
field_border = Color.from_hex_rgb(0xaaa39a)

accent : Color
accent = Color.from_hex_rgb(0x176b87)

selection_color : Color
selection_color = Color.from_hex_rgba(0x4aa9c855)

line_edit_style : PuriLineEditWidget.Style(Color)
line_edit_style = {
	vertical_padding: 8,
	horizontal_padding: 10,
	min_width: 260,
	text_paint: ink,
	caret_paint: accent,
	selection_paint: selection_color,
}

focus! : Model, PuriLineEdit.LineEditSelection => Model
focus! = |model, selection| { ..model, selection: Some(selection) }

change! : Model, Str, PuriLineEdit.LineEditSelection => Model
change! = |model, draft, selection| { ..model, draft, selection: Some(selection) }

submit! : Model => Model
submit! = |model| {
	trimmed = Str.trim(model.draft)
	if Str.is_empty(trimmed) {
		{ ..model, selection: None }
	} else {
		{
			..model,
			draft: "",
			selection: None,
			items: List.append(model.items, trimmed),
		}
	}
}

interaction : Model -> PuriLineEditWidget.Interaction(Model)
interaction = |model| match model.selection {
	Some(selection) => Focused({ selection, change!, blur!: submit! })
	None => Unfocused(focus!)
}

label! : PuriCanvasRocRay.TextStyle, Color, Str => Roclay.Layout(Puri.Frame(PuriCanvasRocRay.Render, Model))
label! = |text_style, paint, string| {
	canvas = PuriCanvasRocRay.canvas(text_style)
	metrics = PuriCanvasRocRay.measure!(text_style, string)
	size = Geometry2d.size(metrics.width, metrics.font_ascent + metrics.font_descent)
	Roclay.leaf(
		size,
		|frame, placement| {
			baseline = Geometry2d.point(placement.rect.x, placement.rect.y + metrics.font_ascent)
			render = PuriCanvas.fill_text!(canvas, frame.render, baseline, paint, string)
			Puri.with_render(render, frame)
		},
	)
}

surface : Color, Color, F32, Geometry2d.Insets(F32), Roclay.Layout(Puri.Frame(PuriCanvasRocRay.Render, Model)) -> Roclay.Layout(Puri.Frame(PuriCanvasRocRay.Render, Model))
surface = |fill, border, border_width, padding, child| {
	parent = Roclay.padding(padding, child)
	Roclay.decorate(
		|frame, placement| {
			with_fill = PuriCanvas.fill_rect!(body_canvas, frame.render, placement.rect, fill)
			with_border = PuriCanvas.stroke_rect!(body_canvas, with_fill, placement.rect, border, border_width)
			Puri.with_render(with_border, frame)
		},
		parent,
	)
}

fill_width : Roclay.Layout(state) -> Roclay.Layout(state)
fill_width = |layout| Roclay.sized({ width: Fill(Roclay.unbounded), height: Fit(Roclay.unbounded) }, layout)

ui! : Model, F32, F32 => Roclay.Layout(Puri.Frame(PuriCanvasRocRay.Render, Model))
ui! = |model, width, height| {
	edit = {
		style: line_edit_style,
		text: model.draft,
		interaction: interaction(model),
	}
	edit_layout = PuriLineEditWidget.line_edit!(body_canvas, measure_body!, edit)
	field = fill_width(surface(field_background, field_border, 1, Geometry2d.insets(2, 2, 2, 2), fill_width(edit_layout)))

	var $children = [
		label!(title_text, ink, "Puri todo"),
		label!(small_text, muted_ink, "Click the field, type a task, then press Enter."),
		field,
	]

	if List.is_empty(model.items) {
		$children = List.append($children, label!(small_text, muted_ink, "No tasks yet."))
	} else {
		for item in model.items {
			row = surface(
				Color.from_hex_rgb(0xe8e3da),
				Color.from_hex_rgb(0xd5cec3),
				1,
				Geometry2d.insets(12, 9, 12, 9),
				label!(small_text, ink, Str.concat("- ", item)),
			)
			$children = List.append($children, fill_width(row))
		}
	}

	root_config = {
		..Roclay.default_box,
		direction: TopToBottom,
		padding: Geometry2d.insets(32, 28, 32, 28),
		gap: 16,
		sizing: { width: Fixed(width), height: Fixed(height) },
	}
	Roclay.box(root_config, $children)
}

modifiers : Host -> PuriHandler.Modifiers
modifiers = |host| {
	shift: Keys.key_down(host.keys, KeyLeftShift) or Keys.key_down(host.keys, KeyRightShift),
	alt: Keys.key_down(host.keys, KeyLeftAlt) or Keys.key_down(host.keys, KeyRightAlt),
	ctrl: Keys.key_down(host.keys, KeyLeftControl) or Keys.key_down(host.keys, KeyRightControl),
	meta: Keys.key_down(host.keys, KeyLeftSuper) or Keys.key_down(host.keys, KeyRightSuper),
}

character : Host, Bool -> [Some(Str), None]
character = |host, shift| {
	pressed = host.keys_pressed
	if Keys.key_pressed(pressed, KeyA) Some(if shift "A" else "a")
	else if Keys.key_pressed(pressed, KeyB) Some(if shift "B" else "b")
	else if Keys.key_pressed(pressed, KeyC) Some(if shift "C" else "c")
	else if Keys.key_pressed(pressed, KeyD) Some(if shift "D" else "d")
	else if Keys.key_pressed(pressed, KeyE) Some(if shift "E" else "e")
	else if Keys.key_pressed(pressed, KeyF) Some(if shift "F" else "f")
	else if Keys.key_pressed(pressed, KeyG) Some(if shift "G" else "g")
	else if Keys.key_pressed(pressed, KeyH) Some(if shift "H" else "h")
	else if Keys.key_pressed(pressed, KeyI) Some(if shift "I" else "i")
	else if Keys.key_pressed(pressed, KeyJ) Some(if shift "J" else "j")
	else if Keys.key_pressed(pressed, KeyK) Some(if shift "K" else "k")
	else if Keys.key_pressed(pressed, KeyL) Some(if shift "L" else "l")
	else if Keys.key_pressed(pressed, KeyM) Some(if shift "M" else "m")
	else if Keys.key_pressed(pressed, KeyN) Some(if shift "N" else "n")
	else if Keys.key_pressed(pressed, KeyO) Some(if shift "O" else "o")
	else if Keys.key_pressed(pressed, KeyP) Some(if shift "P" else "p")
	else if Keys.key_pressed(pressed, KeyQ) Some(if shift "Q" else "q")
	else if Keys.key_pressed(pressed, KeyR) Some(if shift "R" else "r")
	else if Keys.key_pressed(pressed, KeyS) Some(if shift "S" else "s")
	else if Keys.key_pressed(pressed, KeyT) Some(if shift "T" else "t")
	else if Keys.key_pressed(pressed, KeyU) Some(if shift "U" else "u")
	else if Keys.key_pressed(pressed, KeyV) Some(if shift "V" else "v")
	else if Keys.key_pressed(pressed, KeyW) Some(if shift "W" else "w")
	else if Keys.key_pressed(pressed, KeyX) Some(if shift "X" else "x")
	else if Keys.key_pressed(pressed, KeyY) Some(if shift "Y" else "y")
	else if Keys.key_pressed(pressed, KeyZ) Some(if shift "Z" else "z")
	else if Keys.key_pressed(pressed, Key0) Some(if shift ")" else "0")
	else if Keys.key_pressed(pressed, Key1) Some(if shift "!" else "1")
	else if Keys.key_pressed(pressed, Key2) Some(if shift "@" else "2")
	else if Keys.key_pressed(pressed, Key3) Some(if shift "#" else "3")
	else if Keys.key_pressed(pressed, Key4) Some(if shift "$" else "4")
	else if Keys.key_pressed(pressed, Key5) Some(if shift "%" else "5")
	else if Keys.key_pressed(pressed, Key6) Some(if shift "^" else "6")
	else if Keys.key_pressed(pressed, Key7) Some(if shift "&" else "7")
	else if Keys.key_pressed(pressed, Key8) Some(if shift "*" else "8")
	else if Keys.key_pressed(pressed, Key9) Some(if shift "(" else "9")
	else None
}

key_event : Host -> [Some(PuriHandler.KeyEvent), None]
key_event = |host| {
	mods = modifiers(host)
	pressed = host.keys_pressed
	key = if Keys.key_pressed(pressed, KeyEnter) Some(Named(Enter))
	else if Keys.key_pressed(pressed, KeyBackspace) Some(Named(Backspace))
	else if Keys.key_pressed(pressed, KeyDelete) Some(Named(Delete))
	else if Keys.key_pressed(pressed, KeyLeft) Some(Named(ArrowLeft))
	else if Keys.key_pressed(pressed, KeyRight) Some(Named(ArrowRight))
	else if Keys.key_pressed(pressed, KeyHome) Some(Named(Home))
	else if Keys.key_pressed(pressed, KeyEnd) Some(Named(End))
	else if Keys.key_pressed(pressed, KeySpace) Some(Named(Space))
	else match character(host, mods.shift) {
		Some(string) => Some(Character(string))
		None => None
	}
	match key {
		Some(value) => Some({ key: value, state: KeyDown, modifiers: mods })
		None => None
	}
}

handled_or : Model, PuriHandler.DispatchResult(Model) -> Model
handled_or = |model, result| match result {
	Handled(next) => next
	Declined => model
}

dispatch_input! : PuriHandler.Handler(Model), Model, Host => Model
dispatch_input! = |handler, model, host| {
	point = Geometry2d.point(host.mouse.x, host.mouse.y)
	mods = modifiers(host)
	if Mouse.button_pressed(host.mouse, Left) {
		event = { position: point, button: Some(Primary), modifiers: mods }
		handled_or(model, PuriHandler.dispatch_pointer_down!(handler, model, event))
	} else if Mouse.button_released(host.mouse, Left) {
		event = { position: point, button: Some(Primary), modifiers: mods }
		handled_or(model, PuriHandler.dispatch_pointer_up!(handler, model, event))
	} else if Mouse.button_down(host.mouse, Left) {
		event = { position: point, modifiers: mods }
		handled_or(model, PuriHandler.dispatch_pointer_move!(handler, model, event))
	} else match key_event(host) {
		Some(event) => handled_or(model, PuriHandler.dispatch_key!(handler, model, event))
		None => model
	}
}

render! : Model, Host => Try(Model, [Exit(I64), ..])
render! = |model, host| {
	screen = Host.get_screen_size!()
	width = I32.to_f32(screen.width)
	height = I32.to_f32(screen.height)
	layout = ui!(model, width, height)
	measured = Roclay.measure(layout)
	placement = Geometry2d.root_placement(Geometry2d.rect(0, 0, width, height))

	Draw.begin_frame!()
	Draw.clear!(background)
	frame = (measured.place!)(Puri.frame({}), placement)
	Draw.end_frame!()

	Ok(dispatch_input!(frame.handler, model, host))
}
