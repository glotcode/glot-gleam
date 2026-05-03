import gleam/dict
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import glot_backend/app_config
import glot_core/api_action
import glot_core/auth/account_model
import glot_core/rate_limit

pub type DynamicConfig {
  DynamicConfig(
    rate_limit_policies: dict.Dict(api_action.ApiAction, RateLimitPolicy),
  )
}

pub type RateLimitPolicy {
  RateLimitPolicy(rules: List(RateLimitRule))
}

pub type RateLimitRule {
  RateLimitRule(match: RateLimitMatch, limits: List(rate_limit.RateLimit))
}

pub type RateLimitMatch {
  AnonymousMatch
  AuthenticatedMatch(
    account_tiers: option.Option(List(account_model.AccountTier)),
  )
}

pub type RateLimitActor {
  AnonymousActor
  AuthenticatedActor(account_tier: account_model.AccountTier)
}

pub fn empty() -> DynamicConfig {
  DynamicConfig(rate_limit_policies: dict.new())
}

pub fn from_entries(
  entries: List(app_config.AppConfigEntry),
) -> Result(DynamicConfig, String) {
  list.fold(entries, Ok(empty()), fn(acc, entry) {
    use config <- result.try(acc)
    apply_entry(config, entry)
  })
}

pub fn lookup_rate_limit_policy(
  config: DynamicConfig,
  action: api_action.ApiAction,
) -> option.Option(RateLimitPolicy) {
  dict.get(config.rate_limit_policies, action)
  |> option.from_result()
}

pub fn select_rate_limits(
  policy: RateLimitPolicy,
  actor: RateLimitActor,
) -> List(rate_limit.RateLimit) {
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

fn apply_entry(
  config: DynamicConfig,
  entry: app_config.AppConfigEntry,
) -> Result(DynamicConfig, String) {
  case entry.namespace {
    "rate_limit" -> decode_rate_limit_policy_entry(config, entry)
    _ -> Ok(config)
  }
}

fn decode_rate_limit_policy_entry(
  config: DynamicConfig,
  entry: app_config.AppConfigEntry,
) -> Result(DynamicConfig, String) {
  use action <- result.try(case api_action.from_string(entry.key) {
    option.Some(action) -> Ok(action)
    option.None -> Error("Invalid rate limit action in app_config key: " <> entry.key)
  })
  use policy <- result.try(
    json.parse(entry.value, rate_limit_policy_decoder())
    |> result.map_error(fn(err) {
      "Failed to decode rate_limit app_config for "
      <> entry.key
      <> ": "
      <> string.inspect(err)
    }),
  )
  Ok(DynamicConfig(
    rate_limit_policies: dict.insert(config.rate_limit_policies, action, policy),
  ))
}

fn rate_limit_policy_decoder() -> decode.Decoder(RateLimitPolicy) {
  use rules <- decode.field("rules", decode.list(rate_limit_rule_decoder()))
  decode.success(RateLimitPolicy(rules: rules))
}

fn rate_limit_rule_decoder() -> decode.Decoder(RateLimitRule) {
  use match <- decode.field("match", rate_limit_match_decoder())
  use limits <- decode.field("limits", decode.list(rate_limit_decoder()))
  decode.success(RateLimitRule(match:, limits:))
}

fn rate_limit_match_decoder() -> decode.Decoder(RateLimitMatch) {
  use actor <- decode.field("actor", decode.string)
  case actor {
    "anonymous" -> decode.success(AnonymousMatch)
    "authenticated" -> {
      use account_tiers <- decode.field(
        "account_tiers",
        decode.optional(decode.list(account_tier_decoder())),
      )
      decode.success(AuthenticatedMatch(account_tiers: account_tiers))
    }
    _ -> decode.failure(AnonymousMatch, "RateLimitMatch")
  }
}

fn rate_limit_decoder() -> decode.Decoder(rate_limit.RateLimit) {
  use unit <- decode.field("unit", time_unit_decoder())
  use max_requests <- decode.field("max_requests", decode.int)
  decode.success(rate_limit.RateLimit(unit:, max_requests:))
}

fn time_unit_decoder() -> decode.Decoder(rate_limit.TimeUnit) {
  use value <- decode.then(decode.string)
  case rate_limit.unit_from_string(value) {
    option.Some(unit) -> decode.success(unit)
    option.None -> decode.failure(rate_limit.Minute, "TimeUnit")
  }
}

fn account_tier_decoder() -> decode.Decoder(account_model.AccountTier) {
  use value <- decode.then(decode.string)
  case account_model.account_tier_from_string(value) {
    option.Some(tier) -> decode.success(tier)
    option.None -> decode.failure(account_model.FreeTier, "AccountTier")
  }
}

fn rule_match_priority(
  rule_match: RateLimitMatch,
  actor: RateLimitActor,
) -> option.Option(Int) {
  case rule_match, actor {
    AnonymousMatch, AnonymousActor -> option.Some(1)
    AuthenticatedMatch(account_tiers: option.None), AuthenticatedActor(_) ->
      option.Some(2)
    AuthenticatedMatch(account_tiers: option.Some(account_tiers)), AuthenticatedActor(
      actor_tier,
    ) ->
      case list.contains(account_tiers, actor_tier) {
        True -> option.Some(3)
        False -> option.None
      }
    _, _ -> option.None
  }
}
