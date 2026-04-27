import glot_backend/context
import glot_backend/effect/api_log/api_log_effect
import glot_backend/effect/program_types
import glot_core/helpers/timestamp_helpers

pub fn clean_api_log(ctx: context.Context) -> program_types.Program(Nil) {
  let cutoff =
    timestamp_helpers.days_ago(
      ctx.timestamp,
      ctx.config.cleanup.api_log_retention_days,
    )
  api_log_effect.delete_before(cutoff)
}
