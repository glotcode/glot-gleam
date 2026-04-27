import glot_backend/context
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_core/helpers/timestamp_helpers

pub fn clean_user_actions(ctx: context.Context) -> program_types.Program(Nil) {
  let cutoff =
    timestamp_helpers.days_ago(
      ctx.timestamp,
      ctx.config.cleanup.user_actions_retention_days,
    )
  user_action_effect.delete_before(cutoff)
}
