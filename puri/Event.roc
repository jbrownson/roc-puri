## Portable input payloads used by Puri widgets.
##
## Backends wrap these records in structural tags such as PointerDown, Scroll,
## and Key. Widget handlers accept open tag unions, so a backend may add event
## tags that other widgets neither know nor care about.
import Geometry

Event := [].{

	Modifiers : {
		shift : Bool,
		alt : Bool,
		ctrl : Bool,
		meta : Bool,
	}

	PointerButton := [Primary, Secondary, Middle, Other(U16)]

	PointerButtonEvent : {
		position : Geometry.Point,
		button : [Some(PointerButton), None],
		clicks : U8,
		modifiers : Modifiers,
	}

	## A pointer-position update. The backend may produce this from movement,
	## dragging, or another source appropriate to its input model.
	PointerMoveEvent : {
		position : Geometry.Point,
		modifiers : Modifiers,
	}

	PointerScrollEvent : {
		position : Geometry.Point,
		delta : Geometry.Point,
		modifiers : Modifiers,
	}

	KeyState := [KeyDown, KeyUp]
	NamedKey := [
		ArrowDown,
		ArrowLeft,
		ArrowRight,
		ArrowUp,
		Backspace,
		Delete,
		End,
		Enter,
		Escape,
		Home,
		Space,
		Tab,
	]
	Key := [Character(Str), Named(NamedKey), Physical(U32)]
	KeyEvent : {
		key : Key,
		state : KeyState,
		modifiers : Modifiers,
	}

	## The complete portable input vocabulary. Individual widgets use narrower
	## open rows containing only the cases they handle.
	Events(events) : [PointerDown(PointerButtonEvent), PointerMove(PointerMoveEvent), PointerUp(PointerButtonEvent), Scroll(PointerScrollEvent), Key(KeyEvent), ..events]

	empty_modifiers : Modifiers
	empty_modifiers = { shift: Bool.False, alt: Bool.False, ctrl: Bool.False, meta: Bool.False }
}
