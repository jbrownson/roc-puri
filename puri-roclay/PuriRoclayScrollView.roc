## Adapt Puri's layout-independent vertical scrolling behavior to a Roclay
## controlled container.
import puri.Puri
import puri.PuriCanvas
import puri.PuriScrollView
import roclay.Roclay

PuriRoclayScrollView := [].{

	SetOffset(state) : PuriScrollView.SetOffset(state)

	View(state) : PuriScrollView.View(state)

	vertical! : PuriCanvas.WithClip(Puri.Frame(result, state, PuriScrollView.Events(events))), View(state), Roclay.BoxConfig, Roclay.Layout(Puri.Frame(result, state, PuriScrollView.Events(events))) -> Roclay.Layout(Puri.Frame(result, state, PuriScrollView.Events(events)))
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
