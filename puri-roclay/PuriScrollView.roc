## A vertically scrolling Roclay viewport. Roclay computes and offsets the
## child placement; the supplied scoped clip capability keeps rendering direct
## while Puri captures and bounds the child's transient handlers.
import geometry.Geometry2d
import puri.Puri
import puri.PuriCanvas
import puri.PuriHandler
import roclay.Roclay

PuriScrollView := [].{

	SetOffset(context) : context, F32 => context

	View(context) : {
		offset : F32,
		scroll_to_end : Bool,
		set_offset! : SetOffset(context),
	}

	vertical! : PuriCanvas.WithClip(Puri.Frame(result, context)), View(context), Roclay.BoxConfig, Roclay.Layout(Puri.Frame(result, context)) -> Roclay.Layout(Puri.Frame(result, context))
	vertical! = |with_clip!, view, requested_config, child| {
		config = {
			..requested_config,
			direction: TopToBottom,
			clip: { ..requested_config.clip, vertical: Bool.True },
		}
		Roclay.container(
			config,
			|frame, placement, info, place_kids!| {
				max_offset = F32.max(0, info.laid_out_child_size.height - placement.rect.height)
				offset = if view.scroll_to_end max_offset else F32.min(max_offset, F32.max(0, view.offset))
				captured = Puri.capture!(
					frame,
					|child_frame| with_clip!(
						child_frame,
						placement.clip_rect,
						|clipped_frame| place_kids!(clipped_frame, Geometry2d.point(0, 0 - offset)),
					),
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
				child_handler = PuriHandler.map_focus_targets(PuriHandler.within_pointer_bounds(placement.clip_rect, captured.captured), reveal)
				with_scroll = Puri.register(PuriHandler.on_scroll(scroll!), captured.frame)
				Puri.register(child_handler, with_scroll)
			},
			[child],
		)
	}
}
