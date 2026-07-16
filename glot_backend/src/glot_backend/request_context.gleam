import glot_backend/context
import glot_backend/dynamic_config

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
