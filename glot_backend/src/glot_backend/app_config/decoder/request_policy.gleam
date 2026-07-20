import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option}
import gleam/result
import glot_backend/app_config/decoder/value
import glot_backend/app_config/model/entry.{type AppConfigEntry}
import glot_backend/request_policy/model/config as policy_config
import glot_core/admin_action
import glot_core/auth/account_model
import glot_core/availability_mode
import glot_core/public_action.{type PublicAction}
import glot_core/rate_limit

pub fn availability(
  current: policy_config.AvailabilityConfig,
  entry: AppConfigEntry,
) -> Result(policy_config.AvailabilityConfig, String) {
  case entry.key {
    "mode" -> {
      use decoded <- result.try(value.string("availability", entry))
      case availability_mode.from_string(decoded) {
        option.Some(mode) ->
          Ok(policy_config.AvailabilityConfig(..current, mode: mode))
        option.None ->
          Error(
            "Failed to decode availability app_config for mode: " <> decoded,
          )
      }
    }
    "message" -> {
      use decoded <- result.try(value.string("availability", entry))
      Ok(policy_config.AvailabilityConfig(..current, message: decoded))
    }
    "retry_after_seconds" -> {
      use decoded <- result.try(value.optional_int("availability", entry))
      Ok(
        policy_config.AvailabilityConfig(
          ..current,
          retry_after_seconds: decoded,
        ),
      )
    }
    _ -> Ok(current)
  }
}

pub fn rate_limit(
  entry: AppConfigEntry,
) -> Result(Option(#(PublicAction, policy_config.RateLimitPolicy)), String) {
  case public_action.from_string(entry.key) {
    option.Some(action) -> {
      use policy <- result.try(value.json(
        "rate_limit",
        entry,
        rate_limit_policy_decoder(),
      ))
      Ok(option.Some(#(action, policy)))
    }
    option.None ->
      case admin_action.from_string(entry.key) {
        option.Some(_) -> Ok(option.None)
        option.None ->
          Error("Invalid rate limit action in app_config key: " <> entry.key)
      }
  }
}

pub fn encode_rate_limit_policy(
  policy: policy_config.RateLimitPolicy,
) -> json.Json {
  json.object([
    #("rules", json.array(policy.rules, encode_rate_limit_rule)),
  ])
}

fn rate_limit_policy_decoder() -> decode.Decoder(policy_config.RateLimitPolicy) {
  use rules <- decode.field("rules", decode.list(rate_limit_rule_decoder()))
  decode.success(policy_config.RateLimitPolicy(rules: rules))
}

fn encode_rate_limit_rule(rule: policy_config.RateLimitRule) -> json.Json {
  json.object([
    #("match", encode_rate_limit_match(rule.match)),
    #("limits", json.array(rule.limits, encode_rate_limit)),
  ])
}

fn encode_rate_limit_match(
  rule_match: policy_config.RateLimitMatch,
) -> json.Json {
  case rule_match {
    policy_config.AnonymousMatch ->
      json.object([#("actor", json.string("anonymous"))])
    policy_config.AuthenticatedMatch(account_tiers: account_tiers) ->
      json.object([
        #("actor", json.string("authenticated")),
        #(
          "account_tiers",
          json.nullable(account_tiers, fn(account_tiers) {
            json.array(account_tiers, fn(account_tier) {
              json.string(account_model.account_tier_to_string(account_tier))
            })
          }),
        ),
      ])
  }
}

fn encode_rate_limit(rate_limit_value: rate_limit.RateLimit) -> json.Json {
  json.object([
    #("unit", json.string(rate_limit.unit_to_string(rate_limit_value.unit))),
    #("max_requests", json.int(rate_limit_value.max_requests)),
  ])
}

fn rate_limit_rule_decoder() -> decode.Decoder(policy_config.RateLimitRule) {
  use match <- decode.field("match", rate_limit_match_decoder())
  use limits <- decode.field("limits", decode.list(rate_limit_decoder()))
  decode.success(policy_config.RateLimitRule(match:, limits:))
}

fn rate_limit_match_decoder() -> decode.Decoder(policy_config.RateLimitMatch) {
  use actor <- decode.field("actor", decode.string)
  case actor {
    "anonymous" -> decode.success(policy_config.AnonymousMatch)
    "authenticated" -> {
      use account_tiers <- decode.field(
        "account_tiers",
        decode.optional(decode.list(account_tier_decoder())),
      )
      decode.success(policy_config.AuthenticatedMatch(
        account_tiers: account_tiers,
      ))
    }
    _ -> decode.failure(policy_config.AnonymousMatch, "RateLimitMatch")
  }
}

fn rate_limit_decoder() -> decode.Decoder(rate_limit.RateLimit) {
  use unit <- decode.field("unit", time_unit_decoder())
  use max_requests <- decode.field("max_requests", decode.int)
  decode.success(rate_limit.RateLimit(unit:, max_requests:))
}

fn time_unit_decoder() -> decode.Decoder(rate_limit.TimeUnit) {
  use decoded <- decode.then(decode.string)
  case rate_limit.unit_from_string(decoded) {
    option.Some(unit) -> decode.success(unit)
    option.None -> decode.failure(rate_limit.Minute, "TimeUnit")
  }
}

fn account_tier_decoder() -> decode.Decoder(account_model.AccountTier) {
  use decoded <- decode.then(decode.string)
  case account_model.account_tier_from_string(decoded) {
    option.Some(tier) -> decode.success(tier)
    option.None -> decode.failure(account_model.FreeTier, "AccountTier")
  }
}
