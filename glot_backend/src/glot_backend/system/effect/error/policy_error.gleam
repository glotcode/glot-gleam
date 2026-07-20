import gleam/option
import glot_core/api_action as api_action_model
import glot_core/auth/account_model as account_state_model

pub type PolicyError {
  ReadOnlyModeBlocked(message: String, retry_after_seconds: option.Option(Int))
  MaintenanceModeBlocked(
    message: String,
    retry_after_seconds: option.Option(Int),
  )
  ForbiddenAccountState(
    action: api_action_model.ApiAction,
    account_state: account_state_model.AccountState,
  )
}

pub fn status(err: PolicyError) -> Int {
  case err {
    ReadOnlyModeBlocked(_, _) | MaintenanceModeBlocked(_, _) -> 503
    ForbiddenAccountState(_, _) -> 403
  }
}

pub fn code(err: PolicyError) -> String {
  case err {
    ReadOnlyModeBlocked(_, _) -> "read_only_mode_enabled"
    MaintenanceModeBlocked(_, _) -> "maintenance_mode_enabled"
    ForbiddenAccountState(_, _) -> "account_state_forbidden"
  }
}

pub fn message(err: PolicyError) -> String {
  case err {
    ReadOnlyModeBlocked(message, _) | MaintenanceModeBlocked(message, _) ->
      message
    ForbiddenAccountState(_, _) -> "Account state not allowed"
  }
}

pub fn retry_after_seconds(err: PolicyError) -> option.Option(Int) {
  case err {
    ReadOnlyModeBlocked(_, retry_after_seconds)
    | MaintenanceModeBlocked(_, retry_after_seconds) -> retry_after_seconds
    ForbiddenAccountState(_, _) -> option.None
  }
}

pub fn to_string(err: PolicyError) -> String {
  case err {
    ReadOnlyModeBlocked(_, _) -> "availability:read_only_mode_enabled"
    MaintenanceModeBlocked(_, _) -> "availability:maintenance_mode_enabled"
    ForbiddenAccountState(action, account_state) ->
      "account_state_error:"
      <> api_action_model.to_string(action)
      <> ":"
      <> account_state_model.account_state_to_string(account_state)
  }
}
