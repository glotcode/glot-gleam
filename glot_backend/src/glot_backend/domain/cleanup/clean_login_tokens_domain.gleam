import glot_backend/context
import glot_backend/dynamic_config
import glot_backend/effect/app_config/app_config_effect
import glot_backend/effect/auth/auth_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_core/helpers/timestamp_helpers

pub fn clean_login_tokens(ctx: context.Context) -> program_types.Program(Nil) {
  use config <- program.and_then(app_config_effect.get_dynamic_config())
  let cleanup = dynamic_config.cleanup_config(config)
  let cutoff =
    timestamp_helpers.days_ago(
      ctx.timestamp,
      cleanup.login_tokens_retention_days,
    )
  auth_effect.delete_login_tokens_before(cutoff)
}
