## Layout-independent scrolling behavior. A layout adapter supplies the settled
## viewport, laid-out content size, and a continuation that places the content
## at the requested offset.
import geometry.Geometry2d
import Frame
import Canvas
import Event
import Handler

ScrollView := [].{

	SetOffset(state) : state, F32 => state

	View(state) : {
		offset : F32,
		scroll_to_end : Bool,
		set_offset! : SetOffset(state),
	}

	Events(events) : [PointerDown(Event.PointerButtonEvent), Scroll(Event.PointerScrollEvent), ..events]

	PlaceContent(result, state, event) : Geometry2d.Point(F32) => Frame(result, state, event)

	vertical! : Canvas.WithClip(Frame(result, state, Events(events))), View(state), Frame.Placement, Frame.Size, PlaceContent(result, state, Events(events)) => Frame(result, state, Events(events))
		where [result.default : result, result.plus : result, result -> result]
	vertical! = |with_clip!, view, placement, content_size, place_content!| {
		max_offset = F32.max(0, content_size.height - placement.rect.height)
		offset = if view.scroll_to_end max_offset else F32.min(max_offset, F32.max(0, view.offset))
		child_frame = with_clip!(
			placement.clip_rect,
			|| place_content!(Geometry2d.point(0, 0 - offset)),
		)
		handle_scroll! : Handler.HandleEvent(state, Events(events))
		handle_scroll! = |state, event| match event {
			Scroll(scroll) => if Geometry2d.contains(placement.clip_rect, scroll.position) {
				next = F32.min(max_offset, F32.max(0, offset - scroll.delta.y))
				if next == offset Declined else Handled((view.set_offset!)(state, next))
			} else {
				Declined
			}
			_ => Declined
		}
		dispatch_child! = |state, event| Handler.dispatch!(child_frame.handler, state, event)
		bounded_child_handler = Handler.from_function(
			|state, event| match event {
				PointerDown(pointer) => if Geometry2d.contains(placement.clip_rect, pointer.position) {
					dispatch_child!(state, event)
				} else {
					Declined
				}
				Scroll(scroll) => if Geometry2d.contains(placement.clip_rect, scroll.position) {
					dispatch_child!(state, event)
				} else {
					Declined
				}
				# Moves and releases remain unbounded so a drag that begins
				# inside can complete after the pointer leaves the viewport.
				_ => dispatch_child!(state, event)
			},
		)
		bounded_child = { ..child_frame, handler: bounded_child_handler }
		scroll_frame = Frame.register(Handler.from_function(handle_scroll!), Frame.default())
		scroll_frame + bounded_child
	}
}
