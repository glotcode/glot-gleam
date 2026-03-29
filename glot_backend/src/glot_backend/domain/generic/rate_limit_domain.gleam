import gleam/list
import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import glot_backend/api_action.{type ApiAction}
import glot_backend/program.{type Program}
import glot_core/rate_limit

pub fn enforce_by_ip(
  rate_limits rate_limits: List(rate_limit.RateLimit),
  now now: Timestamp,
  ip ip: Option(String),
  action action: ApiAction,
) -> Program(Nil) {
  use counts <- program.and_then(program.db_count_user_activities_by_ip(
    windows: rate_limit.to_windows(rate_limits, now),
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

  case first_exceeded_rate_limit(rate_limits, counts) {
    option.Some(#(count, rate_limit)) ->
      program.fail(program.TooManyRequestsError(count + 1, rate_limit))
    option.None -> program.succeed(Nil)
  }
}

fn first_exceeded_rate_limit(
  rate_limits: List(rate_limit.RateLimit),
  counts: List(rate_limit.WindowCount),
) -> Option(#(Int, rate_limit.RateLimit)) {
  case rate_limits {
    [] -> option.None
    [first, ..rest] ->
      case lookup_count(first, counts) {
        option.Some(count) if count >= first.max_requests ->
          option.Some(#(count, first))
        _ -> first_exceeded_rate_limit(rest, counts)
      }
  }
}

fn lookup_count(
  rate_limit: rate_limit.RateLimit,
  counts: List(rate_limit.WindowCount),
) -> Option(Int) {
  counts
  |> list.find(fn(row) { row.unit == rate_limit.unit })
  |> option.from_result()
  |> option.map(fn(row) { row.count })
}
