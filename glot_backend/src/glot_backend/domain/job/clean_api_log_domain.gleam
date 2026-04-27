import gleam/time/timestamp
import glot_backend/context
import glot_backend/effect/api_log/api_log_effect
import glot_backend/effect/program_types

pub fn clean_api_log(ctx: context.Context) -> program_types.Program(Nil) {
  let cutoff =
    cutoff_time(ctx.timestamp, ctx.config.cleanup.api_log_retention_days)
  api_log_effect.delete_before(cutoff)
}

fn cutoff_time(
  now: timestamp.Timestamp,
  retention_days: Int,
) -> timestamp.Timestamp {
  let #(seconds, nanos) = timestamp.to_unix_seconds_and_nanoseconds(now)
  let retention_seconds = retention_days * 86_400
  timestamp.from_unix_seconds_and_nanoseconds(
    seconds - retention_seconds,
    nanos,
  )
}
