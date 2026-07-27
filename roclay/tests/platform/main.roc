## Minimal native platform used only by Roclay's effectful conformance tests.
## The host is plain C and the boundary is the C symbol ABI.
platform ""
	requires {
		main! : () => I32
	}
	exposes [TestDebug]
	packages {}
	provides { "roc_main": main_for_host! }
	hosted {
		"hosted_test_case": TestDebug.case!,
		"hosted_expected_rect": TestDebug.expected_rect!,
		"hosted_actual_rect": TestDebug.actual_rect!,
	}
	targets: {
		inputs_dir: "targets/",
		arm64mac: { inputs: ["libhost.a", app] },
		x64mac: { inputs: ["libhost.a", app] },
	}

import TestDebug

main_for_host! : () => I32
main_for_host! = || main!()
