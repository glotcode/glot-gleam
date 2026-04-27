import glot_backend/context
import glot_backend/effect/job_log/job_log_effect
import glot_backend/effect/program_types
import glot_core/helpers/timestamp_helpers

pub fn clean_job_log(ctx: context.Context) -> program_types.Program(Nil) {
  let cutoff =
    timestamp_helpers.days_ago(
      ctx.timestamp,
      ctx.config.cleanup.job_log_retention_days,
    )
  job_log_effect.delete_before(cutoff)
}
