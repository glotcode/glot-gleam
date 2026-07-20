import gleam/list
import gleam/option.{type Option}
import glot_core/auth/account_model
import glot_core/availability_mode.{type AvailabilityMode}
import glot_core/rate_limit.{type RateLimit}

pub type AvailabilityConfig {
  AvailabilityConfig(
    mode: AvailabilityMode,
    message: String,
    retry_after_seconds: Option(Int),
  )
}

pub type RateLimitPolicy {
  RateLimitPolicy(rules: List(RateLimitRule))
}

pub type RateLimitRule {
  RateLimitRule(match: RateLimitMatch, limits: List(RateLimit))
}

pub type RateLimitMatch {
  AnonymousMatch
  AuthenticatedMatch(account_tiers: Option(List(account_model.AccountTier)))
}

pub type RateLimitActor {
  AnonymousActor
  AuthenticatedActor(account_tier: account_model.AccountTier)
}

pub fn select_rate_limits(
  policy: RateLimitPolicy,
  actor: RateLimitActor,
) -> List(RateLimit) {
  policy.rules
  |> list.fold(option.None, fn(best, rule) {
    case rule_match_priority(rule.match, actor) {
      option.None -> best
      option.Some(priority) ->
        case best {
          option.Some(#(best_priority, _)) if best_priority >= priority -> best
          _ -> option.Some(#(priority, rule.limits))
        }
    }
  })
  |> option.map(fn(selected) {
    let #(_priority, limits) = selected
    limits
  })
  |> option.unwrap([])
}

fn rule_match_priority(
  rule_match: RateLimitMatch,
  actor: RateLimitActor,
) -> Option(Int) {
  case rule_match, actor {
    AnonymousMatch, AnonymousActor -> option.Some(1)
    AuthenticatedMatch(account_tiers: option.None), AuthenticatedActor(_) ->
      option.Some(2)
    AuthenticatedMatch(account_tiers: option.Some(account_tiers)),
      AuthenticatedActor(actor_tier)
    ->
      case list.contains(account_tiers, actor_tier) {
        True -> option.Some(3)
        False -> option.None
      }
    _, _ -> option.None
  }
}
