import gleam/list
import gleam/option.{type Option}
import glot_backend/context
import glot_backend/domain/shared/rate_limit_domain
import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_core/api_action.{type ApiAction}
import glot_core/auth/account_model.{type AccountState}
import glot_core/auth/user_model
import glot_core/user_action
import youid/uuid.{type Uuid}

pub type ActionActor {
  Anonymous
  KnownUser(user_id: Uuid, account_state: AccountState)
}

type AccountStatePolicy {
  NoAccountStateRequirement
  AllowedAccountStates(List(AccountState))
}

pub fn enforce(
  ctx ctx: context.Context,
  action action: ApiAction,
  actor actor: ActionActor,
) -> program_types.Program(user_action.UserAction) {
  use _ <- program.and_then(
    enforce_account_state(action, actor)
    |> program.from_result(),
  )

  rate_limit_domain.enforce(
    ctx: ctx,
    user_id: actor_user_id(actor),
    action: action,
  )
}

pub fn actor_from_user(
  maybe_user: Option(user_model.HydratedUser),
) -> ActionActor {
  case maybe_user {
    option.Some(user) ->
      KnownUser(
        user_id: user.identity.id,
        account_state: user.account.identity.account_state,
      )
    option.None -> Anonymous
  }
}

fn enforce_account_state(
  action: ApiAction,
  actor: ActionActor,
) -> Result(Nil, error.Error) {
  case account_state_policy(action) {
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
    KnownUser(user_id, _) -> option.Some(user_id)
  }
}

fn actor_account_state(actor: ActionActor) -> Option(AccountState) {
  case actor {
    Anonymous -> option.None
    KnownUser(_, account_state) -> option.Some(account_state)
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
  error.AccountStateError(error.ForbiddenAccountState(
    action: action,
    account_state: account_state,
  ))
}

fn account_state_policy(action: ApiAction) -> AccountStatePolicy {
  case action {
    api_action.SendLoginTokenAction ->
      AllowedAccountStates([
        account_model.Active,
        account_model.ReadOnly,
      ])
    api_action.LoginAction ->
      AllowedAccountStates([
        account_model.Active,
        account_model.ReadOnly,
      ])
    api_action.GetSessionAction ->
      AllowedAccountStates([
        account_model.Active,
        account_model.ReadOnly,
        account_model.Suspended,
      ])
    api_action.LogoutAction ->
      AllowedAccountStates([
        account_model.Active,
        account_model.ReadOnly,
        account_model.Suspended,
      ])
    api_action.GetAccountAction ->
      AllowedAccountStates([
        account_model.Active,
        account_model.ReadOnly,
      ])
    api_action.UpdateAccountAction ->
      AllowedAccountStates([account_model.Active])
    api_action.ScheduleDeleteAccountAction ->
      AllowedAccountStates([account_model.Active])
    api_action.CancelDeleteAccountAction ->
      AllowedAccountStates([account_model.Active])
    api_action.GetSnippetAction ->
      AllowedAccountStates([
        account_model.Active,
        account_model.ReadOnly,
      ])
    api_action.ListPublicSnippetsAction ->
      AllowedAccountStates([
        account_model.Active,
        account_model.ReadOnly,
      ])
    api_action.ListSessionSnippetsAction ->
      AllowedAccountStates([
        account_model.Active,
        account_model.ReadOnly,
      ])
    api_action.CreateSnippetAction ->
      AllowedAccountStates([account_model.Active])
    api_action.UpdateSnippetAction ->
      AllowedAccountStates([account_model.Active])
    api_action.DeleteSnippetAction ->
      AllowedAccountStates([account_model.Active])
    api_action.RunAction -> AllowedAccountStates([account_model.Active])
  }
}
