import gleam/dict
import gleam/list
import gleam/option.{type Option}
import glot_backend/api_action.{type ApiAction}
import glot_backend/context
import glot_backend/effect
import glot_backend/log
import glot_core/rate_limit
import youid/uuid.{type Uuid}

pub fn enforce(
  ctx ctx: context.Context,
  user_id user_id: Option(Uuid),
  action action: ApiAction,
) -> effect.Program(effect.DbCommand) {
  let action_rate_limits = lookup_rate_limits(ctx.config.rate_limits, action)

  use _ <- effect.and_then(effect.when(
    list.is_empty(action_rate_limits),
    effect.warn(
      log.singleton(
        log.object("rate_limit", [
          log.string("message", "No rate limits configured for this action"),
          log.string("action", api_action.to_string(action)),
        ]),
      ),
    ),
  ))

  let counts_effect = case user_id {
    option.Some(user_id) ->
      effect.db_count_user_actions_by_user(
        windows: rate_limit.to_windows(action_rate_limits, ctx.timestamp),
        user_id: option.Some(user_id),
        action: action,
      )
    option.None ->
      effect.db_count_user_actions_by_ip(
        windows: rate_limit.to_windows(action_rate_limits, ctx.timestamp),
        ip: ctx.client_info.ip,
        action: action,
      )
  }

  use counts <- effect.and_then(counts_effect)
  use _ <- effect.and_then(
    check_rate_limit(action_rate_limits, counts)
    |> effect.from_result(),
  )
  use id <- effect.and_then(effect.uuid_v7())

  effect.succeed(effect.DbInsertUserAction(
    id: id,
    request_id: ctx.request_id,
    action: action,
    ip: ctx.client_info.ip,
    user_id: user_id,
    created_at: ctx.timestamp,
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
) -> Result(Nil, effect.Error) {
  case first_exceeded_rate_limit(rate_limits, counts) {
    option.Some(#(count, rate_limit)) ->
      Error(effect.TooManyRequestsError(count + 1, rate_limit))
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
