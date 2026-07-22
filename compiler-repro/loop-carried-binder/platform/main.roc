platform ""
	requires {
		main! : () => I32
	}
	exposes []
	packages {}
	provides { "roc_main": main_for_host! }
	targets: {
		inputs_dir: "targets/",
		arm64mac: { inputs: ["libhost.a", app] },
		x64mac: { inputs: ["libhost.a", app] },
		wasm32: { inputs: ["host.wasm", app] },
	}

main_for_host! : () => I32
main_for_host! = || main!()
