import gleam/dict
import gleam/list
import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import glot_backend/api_action.{type ApiAction}
import glot_backend/context
import glot_backend/program.{type Program}
import glot_core/rate_limit
import youid/uuid.{type Uuid}

pub fn enforce(
  ctx ctx: context.Context,
  rate_limits rate_limits: context.RateLimitsConfig,
  now now: Timestamp,
  ip ip: Option(String),
  user_id user_id: Option(Uuid),
  action action: ApiAction,
) -> Program(program.DbCommand) {
  let action_rate_limits = lookup_rate_limits(rate_limits, action)
  let counts_program = case user_id {
    option.Some(user_id) ->
      program.db_count_user_actions_by_user(
        windows: rate_limit.to_windows(action_rate_limits, now),
        user_id: option.Some(user_id),
        action: action,
      )
    option.None ->
      program.db_count_user_actions_by_ip(
        windows: rate_limit.to_windows(action_rate_limits, now),
        ip: ip,
        action: action,
      )
  }

  use counts <- program.and_then(counts_program)
  use _ <- program.and_then(
    check_rate_limit(action_rate_limits, counts)
    |> program.from_result(),
  )
  use id <- program.and_then(program.uuid_v7())

  program.succeed(program.DbInsertUserAction(
    id: id,
    request_id: ctx.request_id,
    action: action,
    ip: ip,
    user_id: user_id,
    created_at: now,
  ))
}

fn lookup_rate_limits(
  rate_limits: context.RateLimitsConfig,
  action: ApiAction,
) -> List(rate_limit.RateLimit) {
  case dict.get(rate_limits, action) {
    Ok(rate_limits) -> rate_limits
    Error(_) -> []
  }
}

fn check_rate_limit(
  rate_limits: List(rate_limit.RateLimit),
  counts: List(rate_limit.WindowCount),
) -> Result(Nil, program.Error) {
  case first_exceeded_rate_limit(rate_limits, counts) {
    option.Some(#(count, rate_limit)) ->
      Error(program.TooManyRequestsError(count + 1, rate_limit))
    option.None -> Ok(Nil)
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
