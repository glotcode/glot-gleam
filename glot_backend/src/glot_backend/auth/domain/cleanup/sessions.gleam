import gleam/time/timestamp
import glot_backend/app_config/effect/effect as app_config_effect
import glot_backend/app_config/model/config as dynamic_config
import glot_backend/auth/effect/session as session_effect
import glot_backend/system/effect/program
import glot_backend/system/effect/program_types
import glot_backend/system/request/context

pub fn clean_sessions(ctx: context.Context) -> program_types.Program(Nil) {
  use config <- program.and_then(app_config_effect.get_dynamic_config())
  let auth_config = dynamic_config.auth_config(config)
  let created_before =
    subtract_seconds(ctx.timestamp, auth_config.session_token_max_age)
  let token_updated_before =
    subtract_seconds(ctx.timestamp, auth_config.session_idle_timeout_seconds)
  session_effect.delete_expired_sessions(created_before, token_updated_before)
}

fn subtract_seconds(
  ts: timestamp.Timestamp,
  seconds: Int,
) -> timestamp.Timestamp {
  let #(unix_seconds, nanos) = timestamp.to_unix_seconds_and_nanoseconds(ts)
  timestamp.from_unix_seconds_and_nanoseconds(unix_seconds - seconds, nanos)
}
