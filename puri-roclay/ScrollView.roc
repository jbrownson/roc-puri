## Adapt Puri's layout-independent vertical scrolling behavior to a Roclay
## controlled container.
import puri.Frame as PuriFrame
import puri.Canvas
import puri.ScrollView as PuriScrollView
import roclay.Roclay

ScrollView := [].{

	Position : PuriScrollView.Position

	SetPosition(state) : PuriScrollView.SetPosition(state)

	View(state) : PuriScrollView.View(state)

	vertical! : Canvas.WithClip(PuriFrame(result, state, PuriScrollView.Events(events))), View(state), Roclay.BoxConfig, Roclay.Layout(PuriFrame(result, state, PuriScrollView.Events(events))) -> Roclay.Layout(PuriFrame(result, state, PuriScrollView.Events(events)))
		where [result.default : result, result.plus : result, result -> result]
	vertical! = |with_clip!, view, requested_config, child| {
		config = {
			..requested_config,
			direction: TopToBottom,
			clip: { ..requested_config.clip, vertical: Bool.True },
		}
		Roclay.container(
			config,
			|placement, info, place_kids!| {
				PuriScrollView.vertical!(
					with_clip!,
					view,
					placement,
					info.laid_out_child_size,
					place_kids!,
				)
			},
			[child],
		)
	}
}
