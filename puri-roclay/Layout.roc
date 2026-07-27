## Adapt layout-independent Puri widgets to Roclay leaves and decorators.
import geometry.Geometry2d
import puri.Event
import puri.Frame as PuriFrame
import puri.Geometry as PuriGeometry
import puri.Handler
import roclay.Roclay

Layout := [].{

	leaf : PuriGeometry.Size, PuriGeometry.Size, PuriFrame.Widget(result, state, event) -> Roclay.Layout(PuriFrame(result, state, event))
	leaf = |preferred_size, minimum_size, widget!| {
		Roclay.leaf_with_minimum(
			preferred_size,
			minimum_size,
			widget!,
		)
	}

	decorate : PuriFrame.Widget(result, state, event), Roclay.Layout(PuriFrame(result, state, event)) -> Roclay.Layout(PuriFrame(result, state, event))
	decorate = |widget!, child| {
		Roclay.decorate(
			widget!,
			child,
		)
	}

	## Add layout padding while including it in the child's pointer-down hit
	## area. Presses in the padding are forwarded at the nearest point in the
	## child; other events pass through unchanged.
	hit_padding : PuriGeometry.Insets, Roclay.Layout(PuriFrame(result, state, [PointerDown(Event.PointerButtonEvent), ..events])) -> Roclay.Layout(PuriFrame(result, state, [PointerDown(Event.PointerButtonEvent), ..events]))
	hit_padding = |insets, child| {
		config = { ..Roclay.default_box, padding: insets }
		Roclay.container(
			config,
			|placement, _info, place_child!| {
				child_frame = place_child!(Roclay.zero_point)
				child_rect = Geometry2d.inset_rect(insets, placement.rect)
				child_clip = Geometry2d.intersect_rect(child_rect, placement.clip_rect)

				handle_event! : Handler.HandleEvent(state, [PointerDown(Event.PointerButtonEvent), ..events])
				handle_event! = |state, event| match event {
					PointerDown(pointer) if Geometry2d.contains(placement.clip_rect, pointer.position) and child_clip.width > 0 and child_clip.height > 0 => {
						position = {
							x: F32.min(F32.max(pointer.position.x, child_clip.x), Geometry2d.right(child_clip)),
							y: F32.min(F32.max(pointer.position.y, child_clip.y), Geometry2d.bottom(child_clip)),
						}
						Handler.dispatch!(child_frame.handler, state, PointerDown({ ..pointer, position }))
					}
					_ => Handler.dispatch!(child_frame.handler, state, event)
				}
				{ ..child_frame, handler: Handler.from_function(handle_event!) }
			},
			[child],
		)
	}
}
