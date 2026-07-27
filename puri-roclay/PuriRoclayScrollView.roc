## Adapt Puri's layout-independent vertical scrolling behavior to a Roclay
## controlled container.
import puri.Puri
import puri.PuriCanvas
import puri.PuriScrollView
import roclay.Roclay

PuriRoclayScrollView := [].{

	SetOffset(context) : PuriScrollView.SetOffset(context)

	View(context) : PuriScrollView.View(context)

	vertical! : PuriCanvas.WithClip(Puri.Frame(result, context)), View(context), Roclay.BoxConfig, Roclay.Layout(Puri.Frame(result, context)) -> Roclay.Layout(Puri.Frame(result, context))
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
