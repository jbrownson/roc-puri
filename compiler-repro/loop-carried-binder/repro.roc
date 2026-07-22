app [main!] { pf: platform "./platform/main.roc" }

main! = || {
	var $x = 0
	var $y = 0
	for flag in [False] {
		$y = if flag {
			$x = 1
			0
		} else 0
	}
	$x + $y
}
