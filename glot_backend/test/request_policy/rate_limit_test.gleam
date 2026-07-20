import gleam/option
import glot_backend/request_policy/model/config as request_policy_config
import glot_core/auth/account_model
import glot_core/rate_limit

pub fn rate_limit_policy_prefers_tier_specific_rule_test() {
  let policy =
    request_policy_config.RateLimitPolicy(rules: [
      request_policy_config.RateLimitRule(
        match: request_policy_config.AnonymousMatch,
        limits: [rate_limit.RateLimit(unit: rate_limit.Minute, max_requests: 2)],
      ),
      request_policy_config.RateLimitRule(
        match: request_policy_config.AuthenticatedMatch(
          account_tiers: option.None,
        ),
        limits: [rate_limit.RateLimit(unit: rate_limit.Minute, max_requests: 5)],
      ),
      request_policy_config.RateLimitRule(
        match: request_policy_config.AuthenticatedMatch(
          account_tiers: option.Some([
            account_model.FreeTier,
          ]),
        ),
        limits: [rate_limit.RateLimit(unit: rate_limit.Minute, max_requests: 9)],
      ),
    ])

  assert request_policy_config.select_rate_limits(
      policy,
      request_policy_config.AuthenticatedActor(
        account_tier: account_model.FreeTier,
      ),
    )
    == [rate_limit.RateLimit(unit: rate_limit.Minute, max_requests: 9)]
}

pub fn rate_limit_policy_matches_free_plus_rule_test() {
  let policy =
    request_policy_config.RateLimitPolicy(rules: [
      request_policy_config.RateLimitRule(
        match: request_policy_config.AuthenticatedMatch(
          account_tiers: option.None,
        ),
        limits: [rate_limit.RateLimit(unit: rate_limit.Minute, max_requests: 5)],
      ),
      request_policy_config.RateLimitRule(
        match: request_policy_config.AuthenticatedMatch(
          account_tiers: option.Some([
            account_model.FreePlusTier,
          ]),
        ),
        limits: [
          rate_limit.RateLimit(unit: rate_limit.Minute, max_requests: 12),
        ],
      ),
    ])

  assert request_policy_config.select_rate_limits(
      policy,
      request_policy_config.AuthenticatedActor(
        account_tier: account_model.FreePlusTier,
      ),
    )
    == [rate_limit.RateLimit(unit: rate_limit.Minute, max_requests: 12)]
}

pub fn rate_limit_policy_falls_back_to_anonymous_rule_test() {
  let policy =
    request_policy_config.RateLimitPolicy(rules: [
      request_policy_config.RateLimitRule(
        match: request_policy_config.AnonymousMatch,
        limits: [rate_limit.RateLimit(unit: rate_limit.Hour, max_requests: 10)],
      ),
    ])

  assert request_policy_config.select_rate_limits(
      policy,
      request_policy_config.AnonymousActor,
    )
    == [rate_limit.RateLimit(unit: rate_limit.Hour, max_requests: 10)]
}
