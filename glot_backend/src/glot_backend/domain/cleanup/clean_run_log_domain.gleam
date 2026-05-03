import glot_backend/context
import glot_backend/effect/program_types
import glot_backend/effect/run_log/run_log_effect
import glot_core/helpers/timestamp_helpers

pub fn clean_run_log(ctx: context.Context) -> program_types.Program(Nil) {
  let cutoff =
    timestamp_helpers.days_ago(
      ctx.timestamp,
      ctx.config.cleanup.run_log_retention_days,
    )
  run_log_effect.delete_before(cutoff)
}
