import gleam/list
import gleam/option
import glot_backend/context
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/dynamic_config
import glot_backend/effect/app_config/app_config_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_core/admin/rate_limit_config_dto
import glot_core/admin_action
import glot_core/api_action
import glot_core/public_action

pub fn get_rate_limit_policies(
  ctx: context.Context,
) -> program_types.Program(rate_limit_config_dto.RateLimitPoliciesResponse) {
  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.admin(admin_action.GetAdminRateLimitPoliciesAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use config <- program.and_then(app_config_effect.get_dynamic_config())
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  let policies =
    dynamic_config.list_rate_limit_policies(config)
    |> list.map(fn(pair) {
      let #(action, policy) = pair
      rate_limit_policy_response(action, policy)
    })

  program.succeed(rate_limit_config_dto.RateLimitPoliciesResponse(
    policies: policies,
  ))
}

fn rate_limit_policy_response(
  action: public_action.PublicAction,
  policy: dynamic_config.RateLimitPolicy,
) -> rate_limit_config_dto.RateLimitPolicyResponse {
  rate_limit_config_dto.RateLimitPolicyResponse(
    action: action,
    rules: list.map(policy.rules, dto_rule_from_policy_rule),
  )
}

fn dto_rule_from_policy_rule(
  rule: dynamic_config.RateLimitRule,
) -> rate_limit_config_dto.RateLimitRule {
  rate_limit_config_dto.RateLimitRule(
    match: dto_match_from_policy_match(rule.match),
    limits: rule.limits,
  )
}

fn dto_match_from_policy_match(
  rule_match: dynamic_config.RateLimitMatch,
) -> rate_limit_config_dto.RuleMatch {
  case rule_match {
    dynamic_config.AnonymousMatch -> rate_limit_config_dto.AnonymousMatch
    dynamic_config.AuthenticatedMatch(account_tiers: account_tiers) ->
      rate_limit_config_dto.AuthenticatedMatch(
        account_tiers: option.unwrap(account_tiers, []),
      )
  }
}
