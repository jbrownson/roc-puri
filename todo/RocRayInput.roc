## Translate RocRay's frame snapshot into Puri's renderer-independent input events.
##
## This belongs in a reusable Puri–RocRay integration package, not Todo. It is
## app-local because current Roc packages cannot depend on the selected
## platform or import its `rr` modules. See ../ROC_NOTES.md.
##
## RocRay currently exposes key positions rather than an entered-text queue, so
## character input here intentionally follows a US ASCII keyboard layout.
import geometry.Geometry2d
import puri.Event
import rr.Host
import rr.Keys
import rr.Mouse

RocRayInput := [].{

	InputEvent : Event.Events([])

	modifiers : Host -> Event.Modifiers
	modifiers = |host| {
		shift: Keys.key_down(host.keys, KeyLeftShift) or Keys.key_down(host.keys, KeyRightShift),
		alt: Keys.key_down(host.keys, KeyLeftAlt) or Keys.key_down(host.keys, KeyRightAlt),
		ctrl: Keys.key_down(host.keys, KeyLeftControl) or Keys.key_down(host.keys, KeyRightControl),
		meta: Keys.key_down(host.keys, KeyLeftSuper) or Keys.key_down(host.keys, KeyRightSuper),
	}

	# GLFW reports macOS high-resolution scroll movement in tenths of a point.
	macos_scroll_points_per_unit : F32
	macos_scroll_points_per_unit = 10

	## RocRay supplies a per-frame snapshot rather than an ordered event queue.
	## Preserve every supported change in deterministic pointer, scroll, then key
	## order; the relative chronology of simultaneous device changes is unknown.
	events! : Host => List(InputEvent)
	events! = |host| {
		point = Geometry2d.point(host.mouse.x, host.mouse.y)
		mods = RocRayInput.modifiers(host)
		scroll = Mouse.scroll_delta!()
		var $events = []
		mouse_pressed = Mouse.button_pressed(host.mouse, Left)
		mouse_released = Mouse.button_released(host.mouse, Left)
		if mouse_pressed {
			clicks = Mouse.click_count!(host.timestamp_nanos, host.mouse.x, host.mouse.y)
			event = { position: point, button: Some(Primary), clicks, modifiers: mods }
			$events = List.append($events, PointerDown(event))
		}
		if mouse_released {
			event = { position: point, button: Some(Primary), clicks: 0, modifiers: mods }
			$events = List.append($events, PointerUp(event))
		}
		if !(mouse_pressed) and !(mouse_released) and Mouse.button_down(host.mouse, Left) {
			event = { position: point, modifiers: mods }
			$events = List.append($events, PointerMove(event))
		}
		if scroll.x != 0 or scroll.y != 0 {
			# Keep Puri's backend-neutral event in display units, not wheel notches.
			scale = RocRayInput.macos_scroll_points_per_unit
			event = { position: point, delta: Geometry2d.point(scroll.x * scale, scroll.y * scale), modifiers: mods }
			$events = List.append($events, Scroll(event))
		}
		for binding in character_bindings {
			if Keys.key_pressed(host.keys_pressed, binding.physical) {
				string = if mods.shift binding.shifted else binding.plain
				event = { key: Character(string), state: KeyDown, modifiers: mods }
				$events = List.append($events, Key(event))
			}
		}
		for binding in named_bindings {
			if Keys.key_pressed(host.keys_pressed, binding.physical) {
				event = { key: Named(binding.key), state: KeyDown, modifiers: mods }
				$events = List.append($events, Key(event))
			}
		}
		$events
	}
}

NamedBinding : {
	physical : Keys.KeyboardKey,
	key : Event.NamedKey,
}

CharacterBinding : {
	physical : Keys.KeyboardKey,
	plain : Str,
	shifted : Str,
}

named_bindings : List(NamedBinding)
named_bindings = [
	{ physical: KeyEnter, key: Enter },
	{ physical: KeyEscape, key: Escape },
	{ physical: KeyTab, key: Tab },
	{ physical: KeyBackspace, key: Backspace },
	{ physical: KeyDelete, key: Delete },
	{ physical: KeyLeft, key: ArrowLeft },
	{ physical: KeyRight, key: ArrowRight },
	{ physical: KeyHome, key: Home },
	{ physical: KeyEnd, key: End },
	{ physical: KeySpace, key: Space },
]

character_bindings : List(CharacterBinding)
character_bindings = [
	{ physical: KeyA, plain: "a", shifted: "A" },
	{ physical: KeyB, plain: "b", shifted: "B" },
	{ physical: KeyC, plain: "c", shifted: "C" },
	{ physical: KeyD, plain: "d", shifted: "D" },
	{ physical: KeyE, plain: "e", shifted: "E" },
	{ physical: KeyF, plain: "f", shifted: "F" },
	{ physical: KeyG, plain: "g", shifted: "G" },
	{ physical: KeyH, plain: "h", shifted: "H" },
	{ physical: KeyI, plain: "i", shifted: "I" },
	{ physical: KeyJ, plain: "j", shifted: "J" },
	{ physical: KeyK, plain: "k", shifted: "K" },
	{ physical: KeyL, plain: "l", shifted: "L" },
	{ physical: KeyM, plain: "m", shifted: "M" },
	{ physical: KeyN, plain: "n", shifted: "N" },
	{ physical: KeyO, plain: "o", shifted: "O" },
	{ physical: KeyP, plain: "p", shifted: "P" },
	{ physical: KeyQ, plain: "q", shifted: "Q" },
	{ physical: KeyR, plain: "r", shifted: "R" },
	{ physical: KeyS, plain: "s", shifted: "S" },
	{ physical: KeyT, plain: "t", shifted: "T" },
	{ physical: KeyU, plain: "u", shifted: "U" },
	{ physical: KeyV, plain: "v", shifted: "V" },
	{ physical: KeyW, plain: "w", shifted: "W" },
	{ physical: KeyX, plain: "x", shifted: "X" },
	{ physical: KeyY, plain: "y", shifted: "Y" },
	{ physical: KeyZ, plain: "z", shifted: "Z" },
	{ physical: Key0, plain: "0", shifted: ")" },
	{ physical: Key1, plain: "1", shifted: "!" },
	{ physical: Key2, plain: "2", shifted: "@" },
	{ physical: Key3, plain: "3", shifted: "#" },
	{ physical: Key4, plain: "4", shifted: "$" },
	{ physical: Key5, plain: "5", shifted: "%" },
	{ physical: Key6, plain: "6", shifted: "^" },
	{ physical: Key7, plain: "7", shifted: "&" },
	{ physical: Key8, plain: "8", shifted: "*" },
	{ physical: Key9, plain: "9", shifted: "(" },
	{ physical: KeyApostrophe, plain: "'", shifted: "\"" },
	{ physical: KeyComma, plain: ",", shifted: "<" },
	{ physical: KeyMinus, plain: "-", shifted: "_" },
	{ physical: KeyPeriod, plain: ".", shifted: ">" },
	{ physical: KeySlash, plain: "/", shifted: "?" },
	{ physical: KeySemicolon, plain: ";", shifted: ":" },
	{ physical: KeyEqual, plain: "=", shifted: "+" },
	{ physical: KeyLeftBracket, plain: "[", shifted: "{" },
	{ physical: KeyBackslash, plain: "\\", shifted: "|" },
	{ physical: KeyRightBracket, plain: "]", shifted: "}" },
	{ physical: KeyGrave, plain: "`", shifted: "~" },
]
