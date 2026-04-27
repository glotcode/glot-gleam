import glot_backend/context
import glot_backend/effect/job/job_effect
import glot_backend/effect/program_types
import glot_core/helpers/timestamp_helpers
import glot_core/job/job_model

pub fn clean_jobs(ctx: context.Context) -> program_types.Program(Nil) {
  let cutoff =
    timestamp_helpers.days_ago(
      ctx.timestamp,
      ctx.config.cleanup.jobs_retention_days,
    )
  job_effect.delete_before(cutoff, [job_model.Done])
}
