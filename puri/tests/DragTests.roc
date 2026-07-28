app [main!] {
	test_host: platform "./platform/main.roc",
	geometry: "../../geometry/main.roc",
	puri: "../main.roc",
}

import geometry.Geometry2d
import puri.Drag
import puri.Event
import puri.Frame
import puri.Handler

TestResult := {}.{
	default : () -> TestResult
	default = || {}
}

placement : Frame.Placement
placement = Geometry2d.root_placement(Geometry2d.rect(10, 20, 30, 40))

pointer_button : Geometry2d.Point(F32), [Some(Event.PointerButton), None] -> Event.PointerButtonEvent
pointer_button = |position, button| {
	position,
	button,
	clicks: 1,
	modifiers: Event.empty_modifiers,
}

source_uses_its_settled_placement! : () => Bool
source_uses_its_settled_placement! = || {
	begin! : Drag.Begin(U64)
	begin! = |state, source_placement, pointer| if source_placement == placement and pointer.position == Geometry2d.point(15, 25) state + 1 else state
	source! : Frame.Widget(TestResult, U64, Drag.SourceEvents(events))
	source! = Drag.source(Bool.True, begin!)
	handler = (source!(placement)).handler
	inside = Handler.dispatch!(handler, 3, PointerDown(pointer_button(Geometry2d.point(15, 25), Some(Primary))))
	outside = Handler.dispatch!(handler, 3, PointerDown(pointer_button(Geometry2d.point(5, 25), Some(Primary))))
	secondary = Handler.dispatch!(handler, 3, PointerDown(pointer_button(Geometry2d.point(15, 25), Some(Secondary))))
	inside == Handled(4) and outside == Declined and secondary == Declined
}

motion_lets_the_callback_decline! : () => Bool
motion_lets_the_callback_decline! = || {
	move! : Drag.Move(U64)
	move! = |state, _placement, pointer| if pointer.position.x > 20 Handled(state + 1) else Declined
	motion! : Frame.Widget(TestResult, U64, Drag.MoveEvents(events))
	motion! = Drag.motion(Bool.True, move!)
	handler = (motion!(placement)).handler
	accepted = Handler.dispatch!(handler, 3, PointerMove({ position: Geometry2d.point(25, 30), modifiers: Event.empty_modifiers }))
	declined = Handler.dispatch!(handler, 3, PointerMove({ position: Geometry2d.point(15, 30), modifiers: Event.empty_modifiers }))
	accepted == Handled(4) and declined == Declined
}

release_is_global_to_its_placement! : () => Bool
release_is_global_to_its_placement! = || {
	finish! : Drag.Finish(U64)
	finish! = |state, release_placement, pointer| if release_placement == placement and pointer.position == Geometry2d.point(500, 500) state + 1 else state
	release! : Frame.Widget(TestResult, U64, Drag.ReleaseEvents(events))
	release! = Drag.release(Bool.True, finish!)
	handler = (release!(placement)).handler
	result = Handler.dispatch!(handler, 3, PointerUp(pointer_button(Geometry2d.point(500, 500), Some(Primary))))
	result == Handled(4)
}

disabled_widgets_decline! : () => Bool
disabled_widgets_decline! = || {
	begin! : Drag.Begin(U64)
	begin! = |state, _placement, _pointer| state + 1
	source! : Frame.Widget(TestResult, U64, Drag.SourceEvents(events))
	source! = Drag.source(Bool.False, begin!)
	Handler.dispatch!((source!(placement)).handler, 3, PointerDown(pointer_button(Geometry2d.point(15, 25), Some(Primary)))) == Declined
}

main! = || if source_uses_its_settled_placement!() and motion_lets_the_callback_decline!() and release_is_global_to_its_placement!() and disabled_widgets_decline!() 0 else 1
