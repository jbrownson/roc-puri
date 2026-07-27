## Translate RocRay's frame snapshot into Puri's renderer-independent input events.
## RocRay currently exposes key positions rather than an entered-text queue, so
## character input here intentionally follows a US ASCII keyboard layout.
import geometry.Geometry2d
import puri.Event
import puri.Handler
import rr.Host
import rr.Keys
import rr.Mouse

PuriInputRocRay := [].{

	Events(events) : [PointerDown(Event.PointerButtonEvent), PointerMove(Event.PointerUpdate), PointerUp(Event.PointerButtonEvent), Scroll(Event.PointerScrollEvent), Key(Event.KeyEvent), ..events]

	modifiers : Host -> Event.Modifiers
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
		else if Keys.key_pressed(pressed, KeyApostrophe) Some(if shift "\"" else "'")
		else if Keys.key_pressed(pressed, KeyComma) Some(if shift "<" else ",")
		else if Keys.key_pressed(pressed, KeyMinus) Some(if shift "_" else "-")
		else if Keys.key_pressed(pressed, KeyPeriod) Some(if shift ">" else ".")
		else if Keys.key_pressed(pressed, KeySlash) Some(if shift "?" else "/")
		else if Keys.key_pressed(pressed, KeySemicolon) Some(if shift ":" else ";")
		else if Keys.key_pressed(pressed, KeyEqual) Some(if shift "+" else "=")
		else if Keys.key_pressed(pressed, KeyLeftBracket) Some(if shift "{" else "[")
		else if Keys.key_pressed(pressed, KeyBackslash) Some(if shift "|" else "\\")
		else if Keys.key_pressed(pressed, KeyRightBracket) Some(if shift "}" else "]")
		else if Keys.key_pressed(pressed, KeyGrave) Some(if shift "~" else "`")
		else None
	}

	key_event : Host -> [Some(Event.KeyEvent), None]
	key_event = |host| {
		mods = PuriInputRocRay.modifiers(host)
		pressed = host.keys_pressed
		key = if Keys.key_pressed(pressed, KeyEnter) Some(Named(Enter))
		else if Keys.key_pressed(pressed, KeyEscape) Some(Named(Escape))
		else if Keys.key_pressed(pressed, KeyTab) Some(Named(Tab))
		else if Keys.key_pressed(pressed, KeyBackspace) Some(Named(Backspace))
		else if Keys.key_pressed(pressed, KeyDelete) Some(Named(Delete))
		else if Keys.key_pressed(pressed, KeyLeft) Some(Named(ArrowLeft))
		else if Keys.key_pressed(pressed, KeyRight) Some(Named(ArrowRight))
		else if Keys.key_pressed(pressed, KeyHome) Some(Named(Home))
		else if Keys.key_pressed(pressed, KeyEnd) Some(Named(End))
		else if Keys.key_pressed(pressed, KeySpace) Some(Named(Space))
		else match PuriInputRocRay.character(host, mods.shift) {
			Some(string) => Some(Character(string))
			None => None
		}
		match key {
			Some(value) => Some({ key: value, state: KeyDown, modifiers: mods })
			None => None
		}
	}
	OnUnhandledEscape(state) : state -> state

	handled_or : state, Handler.HandleResult(state) -> state
	handled_or = |state, result| match result {
		Handled(next) => next
		Declined => state
	}

	# GLFW reports macOS high-resolution scroll movement in tenths of a point.
	macos_scroll_points_per_unit : F32
	macos_scroll_points_per_unit = 10

	dispatch! : Handler(state, Events(events)), state, Host, OnUnhandledEscape(state) => state
	dispatch! = |handler, state, host, on_unhandled_escape| {
		point = Geometry2d.point(host.mouse.x, host.mouse.y)
		mods = PuriInputRocRay.modifiers(host)
		scroll = Mouse.scroll_delta!()
		if Mouse.button_pressed(host.mouse, Left) {
			clicks = Mouse.click_count!(host.timestamp_nanos, host.mouse.x, host.mouse.y)
			event = { position: point, button: Some(Primary), clicks, modifiers: mods }
			PuriInputRocRay.handled_or(state, Handler.dispatch!(handler, state, PointerDown(event)))
		} else if Mouse.button_released(host.mouse, Left) {
			event = { position: point, button: Some(Primary), clicks: 0, modifiers: mods }
			PuriInputRocRay.handled_or(state, Handler.dispatch!(handler, state, PointerUp(event)))
		} else if Mouse.button_down(host.mouse, Left) {
			event = { position: point, modifiers: mods }
			PuriInputRocRay.handled_or(state, Handler.dispatch!(handler, state, PointerMove(event)))
		} else if scroll.x != 0 or scroll.y != 0 {
			# Keep Puri's backend-neutral event in display units, not wheel notches.
			scale = PuriInputRocRay.macos_scroll_points_per_unit
			event = { position: point, delta: Geometry2d.point(scroll.x * scale, scroll.y * scale), modifiers: mods }
			PuriInputRocRay.handled_or(state, Handler.dispatch!(handler, state, Scroll(event)))
		} else match PuriInputRocRay.key_event(host) {
			Some(event) => match Handler.dispatch!(handler, state, Key(event)) {
				Handled(next) => next
				Declined => match event.key {
					Named(Escape) => on_unhandled_escape(state)
					_ => state
				}
			}
			None => state
		}
	}
}
