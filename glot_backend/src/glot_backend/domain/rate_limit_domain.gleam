import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import glot_backend/api_action.{type ApiAction}
import glot_backend/program.{type Program}
import glot_core/rate_limit.{type RateLimit}

pub fn enforce_by_ip(
  rate_limit rl: RateLimit,
  now now: Timestamp,
  ip ip: Option(String),
  action action: ApiAction,
) -> Program(Nil) {
  use count <- program.and_then(program.db_count_user_activities_by_ip(
    windows: rate_limit.to_windows([rl], now),
    ip: ip,
    action: action,
  ))

  use id <- program.and_then(program.uuid_v7())
  use _ <- program.and_then(
    program.run_command(program.DbInsertUserActivity(
      id: id,
      action: action,
      ip: ip,
      user_id: option.None,
      created_at: now,
    )),
  )

  case count > rl.max_requests {
    True -> program.fail(program.TooManyRequestsError(count, rl))
    False -> program.succeed(Nil)
  }
}
