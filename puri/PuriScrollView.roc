## Layout-independent scrolling behavior. A layout adapter supplies the settled
## viewport, laid-out content size, and a continuation that places the content
## at the requested offset.
import geometry.Geometry2d
import Puri
import PuriCanvas
import PuriHandler

PuriScrollView := [].{

	SetOffset(context) : context, F32 => context

	View(context) : {
		offset : F32,
		scroll_to_end : Bool,
		set_offset! : SetOffset(context),
	}

	PlaceContent(result, context) : Geometry2d.Point(F32) => Puri.Frame(result, context)

	vertical! : PuriCanvas.WithClip(Puri.Frame(result, context)), View(context), Puri.Placement, Puri.Size, PlaceContent(result, context) => Puri.Frame(result, context)
		where [result.default : result, result.plus : result, result -> result]
	vertical! = |with_clip!, view, placement, content_size, place_content!| {
		max_offset = F32.max(0, content_size.height - placement.rect.height)
		offset = if view.scroll_to_end max_offset else F32.min(max_offset, F32.max(0, view.offset))
		child_frame = with_clip!(
			placement.clip_rect,
			|| place_content!(Geometry2d.point(0, 0 - offset)),
		)
		scroll! : PuriHandler.Dispatch(context, PuriHandler.PointerScrollEvent)
		scroll! = |context, event| if Geometry2d.contains(placement.clip_rect, event.position) {
			next = F32.min(max_offset, F32.max(0, offset - event.delta.y))
			if next == offset Declined else Handled((view.set_offset!)(context, next))
		} else {
			Declined
		}
		reveal = |target| {
			requested = if target.rect.y < placement.rect.y {
				offset - (placement.rect.y - target.rect.y)
			} else if Geometry2d.bottom(target.rect) > Geometry2d.bottom(placement.rect) {
				offset + Geometry2d.bottom(target.rect) - Geometry2d.bottom(placement.rect)
			} else {
				offset
			}
			next = F32.min(max_offset, F32.max(0, requested))
			request_focus! = |context| {
				with_offset = if next == offset context else (view.set_offset!)(context, next)
				(target.request_focus!)(with_offset)
			}
			{ ..target, request_focus! }
		}
		child_handler = PuriHandler.map_focus_targets(PuriHandler.within_pointer_bounds(placement.clip_rect, child_frame.handler), reveal)
		bounded_child = { ..child_frame, handler: child_handler }
		scroll_frame = Puri.register(PuriHandler.on_scroll(scroll!), Puri.Frame.default())
		scroll_frame + bounded_child
	}
}
