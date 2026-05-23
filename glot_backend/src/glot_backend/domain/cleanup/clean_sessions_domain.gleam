import glot_backend/context
import glot_backend/dynamic_config
import glot_backend/effect/app_config/app_config_effect
import glot_backend/effect/auth/auth_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import gleam/time/timestamp

pub fn clean_sessions(ctx: context.Context) -> program_types.Program(Nil) {
  use config <- program.and_then(app_config_effect.get_dynamic_config())
  let auth_config = dynamic_config.auth_config(config)
  let cutoff = subtract_seconds(ctx.timestamp, auth_config.session_token_max_age)
  auth_effect.delete_sessions_before(cutoff)
}

fn subtract_seconds(
  ts: timestamp.Timestamp,
  seconds: Int,
) -> timestamp.Timestamp {
  let #(unix_seconds, nanos) = timestamp.to_unix_seconds_and_nanoseconds(ts)
  timestamp.from_unix_seconds_and_nanoseconds(unix_seconds - seconds, nanos)
}
