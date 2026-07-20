import gleam/list
import gleam/option.{type Option}
import gleam/result
import glot_backend/auth/error as auth_error
import glot_backend/request_policy/api_action/policy.{
  type AccountStatePolicy, type AuthenticationPolicy, type AuthorizationPolicy,
}
import glot_backend/request_policy/rate_limit as rate_limit_policy
import glot_backend/system/effect/basic/basic_effect
import glot_backend/system/effect/error
import glot_backend/system/effect/error/policy_error
import glot_backend/system/effect/program
import glot_backend/system/effect/program_types
import glot_backend/system/request/context
import glot_backend/system/request/hydrated_context as request_context
import glot_core/api_action.{type ApiAction}
import glot_core/auth/account_model.{type AccountState, type AccountTier}
import glot_core/auth/user_model
import glot_core/user_action
import youid/uuid.{type Uuid}

pub type ActionActor {
  Anonymous
  KnownUser(
    user_id: Uuid,
    account_state: AccountState,
    account_tier: AccountTier,
    role: user_model.UserRole,
  )
}

pub fn enforce(
  request_ctx request_ctx: request_context.RequestContext,
  action action: ApiAction,
  actor actor: ActionActor,
) -> program_types.Program(user_action.UserAction) {
  let ctx = request_ctx.context
  let config = request_ctx.dynamic_config
  use _ <- program.and_then(
    enforce_policy(action, actor)
    |> program.from_result(),
  )

  case action {
    api_action.PublicAction(action) ->
      rate_limit_policy.enforce(
        config: config,
        ctx: ctx,
        user_id: actor_user_id(actor),
        account_tier: actor_account_tier(actor),
        action: action,
      )
    api_action.AdminAction(_) -> create_user_action(ctx, actor, action)
  }
}

fn enforce_policy(
  action: ApiAction,
  actor: ActionActor,
) -> Result(Nil, error.Error) {
  let action_policy = policy.for_action(action)
  use _ <- result.try(enforce_authentication(
    action_policy.authentication,
    actor,
  ))
  use _ <- result.try(enforce_authorization(action_policy.authorization, actor))
  use _ <- result.try(enforce_account_state(
    action,
    action_policy.account_state,
    actor,
  ))
  Ok(Nil)
}

pub fn actor_from_user(
  maybe_user: Option(user_model.HydratedUser),
) -> ActionActor {
  case maybe_user {
    option.Some(user) ->
      KnownUser(
        user_id: user.identity.id,
        account_state: user.account.identity.account_state,
        account_tier: user.account.identity.account_tier,
        role: user.identity.role,
      )
    option.None -> Anonymous
  }
}

fn enforce_authentication(
  policy: AuthenticationPolicy,
  actor: ActionActor,
) -> Result(Nil, error.Error) {
  case policy {
    policy.NoAuthenticationRequired -> Ok(Nil)
    policy.RequireAuthentication ->
      case actor {
        Anonymous -> Error(error.auth(auth_error.AuthenticationRequired))
        KnownUser(_, _, _, _) -> Ok(Nil)
      }
  }
}

fn enforce_authorization(
  policy: AuthorizationPolicy,
  actor: ActionActor,
) -> Result(Nil, error.Error) {
  case policy {
    policy.NoSpecialAuthorization -> Ok(Nil)
    policy.RequireAdmin ->
      case actor_role(actor) == option.Some(user_model.AdminUser) {
        True -> Ok(Nil)
        False -> Error(error.auth(auth_error.AdminRequired))
      }
  }
}

fn enforce_account_state(
  action: ApiAction,
  policy: AccountStatePolicy,
  actor: ActionActor,
) -> Result(Nil, error.Error) {
  case policy {
    policy.NoAccountStateRequirement -> Ok(Nil)
    policy.AllowedAccountStates(allowed_account_states) ->
      case actor_account_state(actor) {
        option.None -> Ok(Nil)
        option.Some(account_state) ->
          require_allowed_account_state(
            action,
            account_state,
            allowed_account_states,
          )
      }
  }
}

fn actor_user_id(actor: ActionActor) -> Option(Uuid) {
  case actor {
    Anonymous -> option.None
    KnownUser(user_id, _, _, _) -> option.Some(user_id)
  }
}

fn actor_account_state(actor: ActionActor) -> Option(AccountState) {
  case actor {
    Anonymous -> option.None
    KnownUser(_, account_state, _, _) -> option.Some(account_state)
  }
}

fn actor_account_tier(actor: ActionActor) -> Option(AccountTier) {
  case actor {
    Anonymous -> option.None
    KnownUser(_, _, account_tier, _) -> option.Some(account_tier)
  }
}

fn actor_role(actor: ActionActor) -> Option(user_model.UserRole) {
  case actor {
    Anonymous -> option.None
    KnownUser(_, _, _, role) -> option.Some(role)
  }
}

fn require_allowed_account_state(
  action: ApiAction,
  account_state: AccountState,
  allowed_account_states: List(AccountState),
) -> Result(Nil, error.Error) {
  case list.contains(allowed_account_states, account_state) {
    True -> Ok(Nil)
    False -> Error(forbidden_account_state_error(action, account_state))
  }
}

fn forbidden_account_state_error(
  action: ApiAction,
  account_state: AccountState,
) -> error.Error {
  error.policy(policy_error.ForbiddenAccountState(
    action: action,
    account_state: account_state,
  ))
}

fn create_user_action(
  ctx: context.Context,
  actor: ActionActor,
  action: ApiAction,
) -> program_types.Program(user_action.UserAction) {
  use id <- program.and_then(basic_effect.uuid_v7())
  program.succeed(user_action.UserAction(
    id: id,
    request_id: ctx.request_id,
    action: action,
    ip: actor_ip(actor, ctx),
    user_id: actor_user_id(actor),
    created_at: ctx.timestamp,
  ))
}

fn actor_ip(actor: ActionActor, ctx: context.Context) -> Option(String) {
  case actor {
    Anonymous -> ctx.client_info.ip
    KnownUser(_, _, _, _) -> ctx.client_info.ip
  }
}
