app [main!] {
	test_host: platform "./platform/main.roc",
	geometry: "https://github.com/jbrownson/roc-puri-geometry/releases/download/0.1.0/8YcrEeY7J3K9khuA2ULAcMZvzAbqPzdT9qKCDX9YvqSP.tar.zst",
	puri: "../main.roc",
}

import geometry.Geometry2d
import puri.ClickSeries

recognizes_series! : () => Bool
recognizes_series! = || {
	first = ClickSeries.press(ClickSeries.initial, 1_000_000_000, Geometry2d.point(10, 10))
	second = ClickSeries.press(first.state, 1_200_000_000, Geometry2d.point(11, 9))
	third = ClickSeries.press(second.state, 1_300_000_000, Geometry2d.point(10, 10))
	distant = ClickSeries.press(third.state, 1_400_000_000, Geometry2d.point(20, 10))
	late = ClickSeries.press(distant.state, 2_000_000_001, Geometry2d.point(20, 10))
	backwards = ClickSeries.press(late.state, 1_000_000_000, Geometry2d.point(20, 10))
	first.clicks == 1 and second.clicks == 2 and third.clicks == 3 and distant.clicks == 1 and late.clicks == 1 and backwards.clicks == 1
}

main! = || if recognizes_series!() 0 else 1
