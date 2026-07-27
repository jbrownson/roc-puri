## Portable input payloads used by Puri widgets.
##
## Backends wrap these records in structural tags such as PointerDown, Scroll,
## and Key. Widget handlers accept open tag unions, so a backend may add event
## tags that other widgets neither know nor care about.
import geometry.Geometry2d

PuriEvent := [].{

	Scalar : F32
	Point : Geometry2d.Point(Scalar)

	Modifiers : {
		shift : Bool,
		alt : Bool,
		ctrl : Bool,
		meta : Bool,
	}

	PointerButton := [Primary, Secondary, Middle, Other(U16)]

	PointerButtonEvent : {
		position : Point,
		button : [Some(PointerButton), None],
		clicks : U8,
		modifiers : Modifiers,
	}

	PointerUpdate : {
		position : Point,
		modifiers : Modifiers,
	}

	PointerScrollEvent : {
		position : Point,
		delta : Point,
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

	empty_modifiers : Modifiers
	empty_modifiers = { shift: Bool.False, alt: Bool.False, ctrl: Bool.False, meta: Bool.False }
}
