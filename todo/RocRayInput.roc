## Translate RocRay's frame snapshot into Puri's renderer-independent input events.
##
## This belongs in a reusable Puri–RocRay integration package, not Todo. It is
## app-local because current Roc packages cannot depend on the selected
## platform or import its `rr` modules. See ../ROC_NOTES.md.
##
## RocRay 0.9 supplies Unicode text input in active-keyboard-layout order. Key
## state remains useful for navigation and command shortcuts.
import geometry.Geometry2d
import puri.ClickSeries
import puri.Event
import rr.Host
import rr.Keys

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
	EventBatch : {
		events : List(InputEvent),
		click_series : ClickSeries.State,
	}

	events : Host, ClickSeries.State -> EventBatch
	events = |host, click_series| {
		timestamp_nanos = host.timestamp_nanos
		point = Geometry2d.point(host.mouse.x, host.mouse.y)
		mods = RocRayInput.modifiers(host)
		scroll = host.mouse.scroll_delta()
		var $events = []
		var $click_series = click_series
		mouse_pressed = host.mouse.button_pressed(Left)
		mouse_released = host.mouse.button_released(Left)
		if mouse_pressed {
			click = ClickSeries.press($click_series, timestamp_nanos, point)
			$click_series = click.state
			event = { timestamp_nanos, position: point, button: Some(Primary), clicks: click.clicks, modifiers: mods }
			$events = List.append($events, PointerDown(event))
		}
		if mouse_released {
			event = { timestamp_nanos, position: point, button: Some(Primary), clicks: 0, modifiers: mods }
			$events = List.append($events, PointerUp(event))
		}
		if !(mouse_pressed) and !(mouse_released) and host.mouse.button_down(Left) {
			event = { timestamp_nanos, position: point, modifiers: mods }
			$events = List.append($events, PointerMove(event))
		}
		if scroll.x != 0 or scroll.y != 0 {
			# Keep Puri's backend-neutral event in display units, not wheel notches.
			scale = RocRayInput.macos_scroll_points_per_unit
			event = { timestamp_nanos, position: point, delta: Geometry2d.point(scroll.x * scale, scroll.y * scale), modifiers: mods }
			$events = List.append($events, Scroll(event))
		}
		if mods.meta or mods.ctrl {
			# Command shortcuts may not enter text through the operating system's
			# character queue, but Puri's backend-neutral key represents them as
			# modified characters.
			for binding in shortcut_bindings {
				if Keys.key_pressed(host.keys, binding.physical) {
					event = { timestamp_nanos, key: Character(binding.character), state: KeyDown, modifiers: mods }
					$events = List.append($events, Key(event))
				}
			}
		} else {
			for codepoint in host.text_input {
				character = codepoint_to_string(codepoint)
				if character != "" {
					event = { timestamp_nanos, key: Character(character), state: KeyDown, modifiers: mods }
					$events = List.append($events, Key(event))
				}
			}
		}
		for binding in named_bindings {
			if Keys.key_pressed(host.keys, binding.physical) {
				event = { timestamp_nanos, key: Named(binding.key), state: KeyDown, modifiers: mods }
				$events = List.append($events, Key(event))
			}
		}
		{ events: $events, click_series: $click_series }
	}
}

NamedBinding : {
	physical : Keys.KeyboardKey,
	key : Event.NamedKey,
}

ShortcutBinding : {
	physical : Keys.KeyboardKey,
	character : Str,
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

shortcut_bindings : List(ShortcutBinding)
shortcut_bindings = [
	{ physical: KeyA, character: "a" },
	{ physical: KeyC, character: "c" },
	{ physical: KeyV, character: "v" },
	{ physical: KeyX, character: "x" },
]

codepoint_to_string : U32 -> Str
codepoint_to_string = |codepoint| {
	bytes = if codepoint <= 0x7f {
		[codepoint.to_u8_wrap()]
	} else if codepoint <= 0x7ff {
		[
			(0xc0 + codepoint // 0x40).to_u8_wrap(),
			(0x80 + codepoint % 0x40).to_u8_wrap(),
		]
	} else if codepoint >= 0xd800 and codepoint <= 0xdfff {
		[]
	} else if codepoint <= 0xffff {
		[
			(0xe0 + codepoint // 0x1000).to_u8_wrap(),
			(0x80 + (codepoint // 0x40) % 0x40).to_u8_wrap(),
			(0x80 + codepoint % 0x40).to_u8_wrap(),
		]
	} else if codepoint <= 0x10ffff {
		[
			(0xf0 + codepoint // 0x40000).to_u8_wrap(),
			(0x80 + (codepoint // 0x1000) % 0x40).to_u8_wrap(),
			(0x80 + (codepoint // 0x40) % 0x40).to_u8_wrap(),
			(0x80 + codepoint % 0x40).to_u8_wrap(),
		]
	} else {
		[]
	}
	match Str.from_utf8(bytes) {
		Ok(character) => character
		Err(_) => ""
	}
}

expect codepoint_to_string(0x61) == "a"
expect codepoint_to_string(0x1f426) == "🐦"
