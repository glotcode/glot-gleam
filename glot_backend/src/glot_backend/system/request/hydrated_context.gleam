import glot_backend/app_config/model/config as dynamic_config
import glot_backend/system/request/context

pub type RequestContext {
  RequestContext(
    context: context.Context,
    dynamic_config: dynamic_config.DynamicConfig,
  )
}

pub fn new(
  context: context.Context,
  dynamic_config: dynamic_config.DynamicConfig,
) -> RequestContext {
  RequestContext(context: context, dynamic_config: dynamic_config)
}
