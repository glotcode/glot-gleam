import gleam/dynamic/decode
import gleam/json
import gleam/option
import glot_core/auth/account_model
import glot_core/public_action
import glot_core/rate_limit

pub type RateLimitPoliciesResponse {
  RateLimitPoliciesResponse(policies: List(RateLimitPolicyResponse))
}

pub type RateLimitPolicyResponse {
  RateLimitPolicyResponse(
    action: public_action.PublicAction,
    rules: List(RateLimitRule),
  )
}

pub type UpsertRateLimitPolicyRequest {
  UpsertRateLimitPolicyRequest(
    action: public_action.PublicAction,
    rules: List(RateLimitRule),
  )
}

pub type RateLimitRule {
  RateLimitRule(match: RuleMatch, limits: List(rate_limit.RateLimit))
}

pub type RuleMatch {
  AnonymousMatch
  AuthenticatedMatch(account_tiers: List(account_model.AccountTier))
}

pub fn response_decoder() -> decode.Decoder(RateLimitPoliciesResponse) {
  use policies <- decode.field(
    "policies",
    decode.list(policy_response_decoder()),
  )
  decode.success(RateLimitPoliciesResponse(policies: policies))
}

pub fn policy_response_decoder() -> decode.Decoder(RateLimitPolicyResponse) {
  use action <- decode.field("action", public_action.decoder())
  use rules <- decode.field("rules", decode.list(rule_decoder()))
  decode.success(RateLimitPolicyResponse(action:, rules:))
}

pub fn encode_response(response: RateLimitPoliciesResponse) -> json.Json {
  json.object([
    #("policies", json.array(response.policies, encode_policy_response)),
  ])
}

pub fn encode_policy_response(response: RateLimitPolicyResponse) -> json.Json {
  json.object([
    #("action", public_action.encode(response.action)),
    #("rules", json.array(response.rules, encode_rule)),
  ])
}

pub fn decoder() -> decode.Decoder(UpsertRateLimitPolicyRequest) {
  use action <- decode.field("action", public_action.decoder())
  use rules <- decode.field("rules", decode.list(rule_decoder()))
  decode.success(UpsertRateLimitPolicyRequest(action:, rules:))
}

pub fn rules_decoder() -> decode.Decoder(List(RateLimitRule)) {
  decode.list(rule_decoder())
}

pub fn encode_request(request: UpsertRateLimitPolicyRequest) -> json.Json {
  json.object([
    #("action", public_action.encode(request.action)),
    #("rules", encode_rules(request.rules)),
  ])
}

pub fn encode_rules(rules: List(RateLimitRule)) -> json.Json {
  json.array(rules, encode_rule)
}

pub fn encode_rule(rule: RateLimitRule) -> json.Json {
  json.object([
    #("match", encode_match(rule.match)),
    #("limits", json.array(rule.limits, rate_limit.encode_rate_limit)),
  ])
}

fn encode_match(rule_match: RuleMatch) -> json.Json {
  case rule_match {
    AnonymousMatch -> json.object([#("actor", json.string("anonymous"))])
    AuthenticatedMatch(account_tiers) ->
      json.object([
        #("actor", json.string("authenticated")),
        #(
          "accountTiers",
          json.array(account_tiers, fn(account_tier) {
            json.string(account_model.account_tier_to_string(account_tier))
          }),
        ),
      ])
  }
}

fn rule_decoder() -> decode.Decoder(RateLimitRule) {
  use match <- decode.field("match", match_decoder())
  use limits <- decode.field("limits", decode.list(rate_limit.decoder()))
  decode.success(RateLimitRule(match:, limits:))
}

fn match_decoder() -> decode.Decoder(RuleMatch) {
  use actor <- decode.field("actor", decode.string)
  case actor {
    "anonymous" -> decode.success(AnonymousMatch)
    "authenticated" -> {
      use account_tiers <- decode.field(
        "accountTiers",
        decode.list(account_tier_decoder()),
      )
      decode.success(AuthenticatedMatch(account_tiers: account_tiers))
    }
    _ -> decode.failure(AnonymousMatch, "RuleMatch")
  }
}

fn account_tier_decoder() -> decode.Decoder(account_model.AccountTier) {
  use value <- decode.then(decode.string)
  case account_model.account_tier_from_string(value) {
    option.Some(account_tier) -> decode.success(account_tier)
    option.None -> decode.failure(account_model.FreeTier, "AccountTier")
  }
}
