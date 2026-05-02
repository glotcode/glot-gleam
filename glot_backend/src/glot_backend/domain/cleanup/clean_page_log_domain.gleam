import glot_backend/context
import glot_backend/effect/page_log/page_log_effect
import glot_backend/effect/program_types
import glot_core/helpers/timestamp_helpers

pub fn clean_page_log(ctx: context.Context) -> program_types.Program(Nil) {
  let cutoff =
    timestamp_helpers.days_ago(
      ctx.timestamp,
      ctx.config.cleanup.page_log_retention_days,
    )
  page_log_effect.delete_before(cutoff)
}
