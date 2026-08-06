import Host
import AppConfig

App := [].{
	FramePacing : AppConfig.FramePacing
	CursorMode : AppConfig.CursorMode
	Config : AppConfig.Config

	InitCallback(model, errors) : Host => Try(model, [Exit(I64), ..errors])

	Init(model, errors) : {
		config : Config,
		run! : InitCallback(model, errors),
	}

	default : Config
	default = AppConfig.default

	init : Config, InitCallback(model, errors) -> Init(model, errors)
	init = |config, run!| { config, run! }
}
