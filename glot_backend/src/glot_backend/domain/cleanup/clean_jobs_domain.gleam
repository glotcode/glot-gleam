import glot_backend/context
import glot_backend/dynamic_config
import glot_backend/effect/app_config/app_config_effect
import glot_backend/effect/job/job_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_core/helpers/timestamp_helpers
import glot_core/job/job_model

pub fn clean_jobs(ctx: context.Context) -> program_types.Program(Nil) {
  use config <- program.and_then(app_config_effect.get_dynamic_config())
  let cleanup = dynamic_config.lookup_cleanup_config(config)
  let cutoff =
    timestamp_helpers.days_ago(
      ctx.timestamp,
      cleanup.jobs_retention_days,
    )
  job_effect.delete_before(cutoff, [job_model.Done])
}
