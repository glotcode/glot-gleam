import gleam/list
import gleam/option.{type Option}
import glot_backend/context
import glot_backend/domain/shared/rate_limit_domain
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_core/api_action
import glot_core/admin_action
import glot_core/public_action
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

type AuthenticationPolicy {
  NoAuthenticationRequired
  RequireAuthentication
}

type AuthorizationPolicy {
  NoSpecialAuthorization
  RequireAdmin
}

type AccountStatePolicy {
  NoAccountStateRequirement
  AllowedAccountStates(List(AccountState))
}

type ApiActionPolicy {
  ApiActionPolicy(
    authentication_policy: AuthenticationPolicy,
    authorization_policy: AuthorizationPolicy,
    account_state_policy: AccountStatePolicy,
  )
}

pub fn enforce(
  ctx ctx: context.Context,
  action action: api_action.ApiAction,
  actor actor: ActionActor,
) -> program_types.Program(user_action.UserAction) {
  let policy = action_policy(action)
  use _ <- program.and_then(
    enforce_authentication(policy.authentication_policy, actor)
    |> program.from_result(),
  )
  use _ <- program.and_then(
    enforce_authorization(policy.authorization_policy, actor)
    |> program.from_result(),
  )
  use _ <- program.and_then(
    enforce_account_state(action, policy.account_state_policy, actor)
    |> program.from_result(),
  )

  case action {
    api_action.PublicAction(action) ->
      rate_limit_domain.enforce(
        ctx: ctx,
        user_id: actor_user_id(actor),
        account_tier: actor_account_tier(actor),
        action: action,
      )
    api_action.AdminAction(_) -> create_user_action(ctx, actor, action)
  }
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
    NoAuthenticationRequired -> Ok(Nil)
    RequireAuthentication ->
      case actor {
        Anonymous ->
          Error(error.AuthorizationError(error.AuthenticationRequiredError))
        KnownUser(_, _, _, _) -> Ok(Nil)
      }
  }
}

fn enforce_authorization(
  policy: AuthorizationPolicy,
  actor: ActionActor,
) -> Result(Nil, error.Error) {
  case policy {
    NoSpecialAuthorization -> Ok(Nil)
    RequireAdmin ->
      case actor_role(actor) == option.Some(user_model.AdminUser) {
        True -> Ok(Nil)
        False -> Error(error.AuthorizationError(error.AdminRequiredError))
      }
  }
}

fn enforce_account_state(
  action: api_action.ApiAction,
  policy: AccountStatePolicy,
  actor: ActionActor,
) -> Result(Nil, error.Error) {
  case policy {
    NoAccountStateRequirement -> Ok(Nil)
    AllowedAccountStates(allowed_account_states) ->
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
  action: api_action.ApiAction,
  account_state: AccountState,
  allowed_account_states: List(AccountState),
) -> Result(Nil, error.Error) {
  case list.contains(allowed_account_states, account_state) {
    True -> Ok(Nil)
    False -> Error(forbidden_account_state_error(action, account_state))
  }
}

fn forbidden_account_state_error(
  action: api_action.ApiAction,
  account_state: AccountState,
) -> error.Error {
  error.AccountStateError(error.ForbiddenAccountState(
    action: action,
    account_state: account_state,
  ))
}

fn action_policy(action: api_action.ApiAction) -> ApiActionPolicy {
  case action {
    api_action.PublicAction(action) -> public_policy(action)
    api_action.AdminAction(action) -> admin_policy(action)
  }
}

fn create_user_action(
  ctx: context.Context,
  actor: ActionActor,
  action: api_action.ApiAction,
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

fn public_policy(action: public_action.PublicAction) -> ApiActionPolicy {
  case action {
    public_action.TrackPageviewAction ->
      public_action_policy(NoAccountStateRequirement)
    public_action.GetLanguageVersionAction ->
      public_action_policy(NoAccountStateRequirement)
    public_action.SendLoginTokenAction ->
      public_action_policy(
        AllowedAccountStates([
          account_model.Active,
          account_model.ReadOnly,
        ]),
      )
    public_action.LoginAction ->
      public_action_policy(
        AllowedAccountStates([
          account_model.Active,
          account_model.ReadOnly,
        ]),
      )
    public_action.GetSessionAction ->
      public_action_policy(
        AllowedAccountStates([
          account_model.Active,
          account_model.ReadOnly,
          account_model.Suspended,
        ]),
      )
    public_action.LogoutAction ->
      authenticated_action_policy(
        AllowedAccountStates([
          account_model.Active,
          account_model.ReadOnly,
          account_model.Suspended,
        ]),
      )
    public_action.GetAccountAction ->
      authenticated_action_policy(
        AllowedAccountStates([
          account_model.Active,
          account_model.ReadOnly,
        ]),
      )
    public_action.UpdateAccountAction ->
      authenticated_action_policy(AllowedAccountStates([account_model.Active]))
    public_action.ScheduleDeleteAccountAction ->
      authenticated_action_policy(AllowedAccountStates([account_model.Active]))
    public_action.CancelDeleteAccountAction ->
      authenticated_action_policy(AllowedAccountStates([account_model.Active]))
    public_action.GetSnippetAction ->
      public_action_policy(
        AllowedAccountStates([
          account_model.Active,
          account_model.ReadOnly,
        ]),
      )
    public_action.ListPublicSnippetsAction ->
      public_action_policy(
        AllowedAccountStates([
          account_model.Active,
          account_model.ReadOnly,
        ]),
      )
    public_action.ListSessionSnippetsAction ->
      authenticated_action_policy(
        AllowedAccountStates([
          account_model.Active,
          account_model.ReadOnly,
        ]),
      )
    public_action.CreateSnippetAction ->
      authenticated_action_policy(AllowedAccountStates([account_model.Active]))
    public_action.UpdateSnippetAction ->
      authenticated_action_policy(AllowedAccountStates([account_model.Active]))
    public_action.DeleteSnippetAction ->
      authenticated_action_policy(AllowedAccountStates([account_model.Active]))
    public_action.RunAction ->
      public_action_policy(AllowedAccountStates([account_model.Active]))
  }
}

fn admin_policy(_action: admin_action.AdminAction) -> ApiActionPolicy {
  admin_action_policy(
    AllowedAccountStates([
      account_model.Active,
      account_model.ReadOnly,
    ]),
  )
}

fn public_action_policy(
  account_state_policy: AccountStatePolicy,
) -> ApiActionPolicy {
  ApiActionPolicy(
    authentication_policy: NoAuthenticationRequired,
    authorization_policy: NoSpecialAuthorization,
    account_state_policy: account_state_policy,
  )
}

fn authenticated_action_policy(
  account_state_policy: AccountStatePolicy,
) -> ApiActionPolicy {
  ApiActionPolicy(
    authentication_policy: RequireAuthentication,
    authorization_policy: NoSpecialAuthorization,
    account_state_policy: account_state_policy,
  )
}

fn admin_action_policy(
  account_state_policy: AccountStatePolicy,
) -> ApiActionPolicy {
  ApiActionPolicy(
    authentication_policy: RequireAuthentication,
    authorization_policy: RequireAdmin,
    account_state_policy: account_state_policy,
  )
}
