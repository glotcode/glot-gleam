import glot_backend/app_config/effect/effect as app_config_effect
import glot_backend/app_config/model/config as dynamic_config
import glot_backend/system/effect/program
import glot_backend/system/effect/program_types
import glot_backend/system/request/context
import glot_backend/user_action/effect/effect as user_action_effect
import glot_core/helpers/timestamp_helpers

pub fn clean_user_actions(ctx: context.Context) -> program_types.Program(Nil) {
  use config <- program.and_then(app_config_effect.get_dynamic_config())
  let cleanup = dynamic_config.cleanup_config(config)
  let cutoff =
    timestamp_helpers.days_ago(
      ctx.timestamp,
      cleanup.user_actions_retention_days,
    )
  user_action_effect.delete_before(cutoff)
}
