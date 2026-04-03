import gleam/dict
import gleam/list
import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import glot_backend/context
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_backend/log
import glot_core/api_action.{type ApiAction}
import glot_core/rate_limit
import glot_core/user_action
import youid/uuid.{type Uuid}

pub fn enforce(
  ctx ctx: context.Context,
  user_id user_id: Option(Uuid),
  action action: ApiAction,
) -> program_types.Program(program_types.Program(Nil)) {
  let action_rate_limits = lookup_rate_limits(ctx.config.rate_limits, action)

  use _ <- program.and_then(program.when(
    list.is_empty(action_rate_limits),
    basic_effect.warn(
      log.singleton(
        log.object("rate_limit", [
          log.string("message", "No rate limits configured for this action"),
          log.string("action", api_action.to_string(action)),
        ]),
      ),
    ),
  ))
  use filter <- program.and_then(program.from_option(
    user_action_filter(
      action_rate_limits: action_rate_limits,
      timestamp: ctx.timestamp,
      user_id: user_id,
      ip: ctx.client_info.ip,
      action: action,
    ),
    error.ClientInfoError(error.MissingUserIdAndIpError),
  ))

  use counts <- program.and_then(user_action_effect.count_user_actions(filter))
  use _ <- program.and_then(
    check_rate_limit(action_rate_limits, counts)
    |> program.from_result(),
  )
  use id <- program.and_then(basic_effect.uuid_v7())

  program.succeed(
    user_action_effect.create_user_action(user_action.UserAction(
      id: id,
      request_id: ctx.request_id,
      action: action,
      ip: ctx.client_info.ip,
      user_id: user_id,
      created_at: ctx.timestamp,
    )),
  )
}

fn user_action_filter(
  action_rate_limits action_rate_limits: List(rate_limit.RateLimit),
  timestamp timestamp: Timestamp,
  user_id user_id: Option(Uuid),
  ip ip: Option(String),
  action action: ApiAction,
) -> Option(user_action.UserActionFilter) {
  let windows = rate_limit.to_windows(action_rate_limits, timestamp)

  case user_id, ip {
    option.Some(user_id), _ ->
      option.Some(user_action.UserActionFilter(
        windows: windows,
        action: action,
        count_by: user_action.CountByUser(user_id),
      ))
    option.None, option.Some(ip) ->
      option.Some(user_action.UserActionFilter(
        windows: windows,
        action: action,
        count_by: user_action.CountByIp(ip),
      ))
    option.None, option.None -> option.None
  }
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
) -> Result(Nil, error.Error) {
  case first_exceeded_rate_limit(rate_limits, counts) {
    option.Some(#(count, rate_limit)) ->
      Error(error.TooManyRequestsError(count + 1, rate_limit))
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
