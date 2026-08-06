## Portable input payloads used by Puri widgets.
##
## Backends wrap these records in structural tags such as PointerDown, Scroll,
## and Key. Widget handlers accept open tag unions, so a backend may add event
## tags that other widgets neither know nor care about. Timestamps are
## monotonic nanoseconds with an unspecified origin.
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
		timestamp_nanos : U64,
		position : Geometry.Point,
		button : [Some(PointerButton), None],
		clicks : U8,
		modifiers : Modifiers,
	}

	## A pointer-position update. The backend may produce this from movement,
	## dragging, or another source appropriate to its input model.
	PointerMoveEvent : {
		timestamp_nanos : U64,
		position : Geometry.Point,
		modifiers : Modifiers,
	}

	PointerScrollEvent : {
		timestamp_nanos : U64,
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
		timestamp_nanos : U64,
		key : Key,
		state : KeyState,
		modifiers : Modifiers,
	}
	TimePassedEvent : {
		timestamp_nanos : U64,
	}

	## The complete portable input vocabulary. Individual widgets use narrower
	## open rows containing only the cases they handle.
	Events(events) : [
		PointerDown(PointerButtonEvent),
		PointerMove(PointerMoveEvent),
		PointerUp(PointerButtonEvent),
		Scroll(PointerScrollEvent),
		Key(KeyEvent),
		TimePassed(TimePassedEvent),
		..events,
	]

	timestamp_nanos : Events([]) -> U64
	timestamp_nanos = |event| match event {
		PointerDown(data) => data.timestamp_nanos
		PointerMove(data) => data.timestamp_nanos
		PointerUp(data) => data.timestamp_nanos
		Scroll(data) => data.timestamp_nanos
		Key(data) => data.timestamp_nanos
		TimePassed(data) => data.timestamp_nanos
	}

	empty_modifiers : Modifiers
	empty_modifiers = { shift: Bool.False, alt: Bool.False, ctrl: Bool.False, meta: Bool.False }
}
