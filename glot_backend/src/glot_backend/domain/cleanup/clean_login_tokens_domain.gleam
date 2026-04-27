import glot_backend/context
import glot_backend/effect/auth/auth_effect
import glot_backend/effect/program_types
import glot_core/helpers/timestamp_helpers

pub fn clean_login_tokens(ctx: context.Context) -> program_types.Program(Nil) {
  let cutoff =
    timestamp_helpers.days_ago(
      ctx.timestamp,
      ctx.config.cleanup.login_tokens_retention_days,
    )
  auth_effect.delete_login_tokens_before(cutoff)
}
