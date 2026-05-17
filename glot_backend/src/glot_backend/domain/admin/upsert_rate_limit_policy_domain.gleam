import gleam/dynamic
import gleam/list
import gleam/option
import glot_backend/context
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/dynamic_config
import glot_backend/effect/app_config/app_config_effect
import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_core/admin/rate_limit_config_dto
import glot_core/admin_action
import glot_core/api_action
import glot_core/validation_error

pub fn upsert_rate_limit_policy(
  ctx: context.Context,
  request: rate_limit_config_dto.UpsertRateLimitPolicyRequest,
) -> program_types.Program(rate_limit_config_dto.RateLimitPolicyResponse) {
  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.admin(admin_action.UpsertAdminRateLimitPolicyAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use _ <- program.and_then(validate_request(request))
  use _ <- program.and_then(app_config_effect.upsert_rate_limit_policy(
    request.action,
    policy_from_request(request),
    ctx.timestamp,
  ))
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(rate_limit_config_dto.RateLimitPolicyResponse(
    action: request.action,
    rules: request.rules,
  ))
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(rate_limit_config_dto.UpsertRateLimitPolicyRequest) {
  program.decode_dynamic(data, rate_limit_config_dto.decoder())
}

fn validate_request(
  request: rate_limit_config_dto.UpsertRateLimitPolicyRequest,
) -> program_types.Program(Nil) {
  case list.is_empty(request.rules) {
    True -> program.fail(error.validation(validation_error.RulesMissing))
    False -> program.succeed(Nil)
  }
}

fn policy_from_request(
  request: rate_limit_config_dto.UpsertRateLimitPolicyRequest,
) -> dynamic_config.RateLimitPolicy {
  dynamic_config.RateLimitPolicy(rules: list.map(
    request.rules,
    policy_rule_from_dto_rule,
  ))
}

fn policy_rule_from_dto_rule(
  rule: rate_limit_config_dto.RateLimitRule,
) -> dynamic_config.RateLimitRule {
  dynamic_config.RateLimitRule(
    match: policy_match_from_dto_match(rule.match),
    limits: rule.limits,
  )
}

fn policy_match_from_dto_match(
  rule_match: rate_limit_config_dto.RuleMatch,
) -> dynamic_config.RateLimitMatch {
  case rule_match {
    rate_limit_config_dto.AnonymousMatch -> dynamic_config.AnonymousMatch
    rate_limit_config_dto.AuthenticatedMatch(account_tiers: account_tiers) ->
      case list.is_empty(account_tiers) {
        True -> dynamic_config.AuthenticatedMatch(account_tiers: option.None)
        False ->
          dynamic_config.AuthenticatedMatch(account_tiers: option.Some(
            account_tiers,
          ))
      }
  }
}
