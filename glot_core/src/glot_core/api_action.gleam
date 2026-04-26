import gleam/dynamic/decode
import gleam/json

pub type ApiAction {
  RunAction
  GetSessionAction
  LogoutAction
  GetAccountAction
  UpdateAccountAction
  ScheduleDeleteAccountAction
  CancelDeleteAccountAction
  GetSnippetAction
  ListPublicSnippetsAction
  ListSessionSnippetsAction
  CreateSnippetAction
  UpdateSnippetAction
  DeleteSnippetAction
  SendLoginTokenAction
  LoginAction
}

pub fn decoder() -> decode.Decoder(ApiAction) {
  use action <- decode.then(decode.string)
  case action {
    "run" -> decode.success(RunAction)
    "get_session" -> decode.success(GetSessionAction)
    "logout" -> decode.success(LogoutAction)
    "get_account" -> decode.success(GetAccountAction)
    "update_account" -> decode.success(UpdateAccountAction)
    "schedule_delete_account" -> decode.success(ScheduleDeleteAccountAction)
    "cancel_delete_account" -> decode.success(CancelDeleteAccountAction)
    "get_snippet" -> decode.success(GetSnippetAction)
    "list_public_snippets" -> decode.success(ListPublicSnippetsAction)
    "list_session_snippets" -> decode.success(ListSessionSnippetsAction)
    "create_snippet" -> decode.success(CreateSnippetAction)
    "update_snippet" -> decode.success(UpdateSnippetAction)
    "delete_snippet" -> decode.success(DeleteSnippetAction)
    "send_login_token" -> decode.success(SendLoginTokenAction)
    "login" -> decode.success(LoginAction)
    _ -> decode.failure(RunAction, "ApiAction")
  }
}

pub fn encode(action: ApiAction) -> json.Json {
  action |> to_string |> json.string
}

pub fn to_string(action: ApiAction) -> String {
  case action {
    RunAction -> "run"
    GetSessionAction -> "get_session"
    LogoutAction -> "logout"
    GetAccountAction -> "get_account"
    UpdateAccountAction -> "update_account"
    ScheduleDeleteAccountAction -> "schedule_delete_account"
    CancelDeleteAccountAction -> "cancel_delete_account"
    GetSnippetAction -> "get_snippet"
    ListPublicSnippetsAction -> "list_public_snippets"
    ListSessionSnippetsAction -> "list_session_snippets"
    CreateSnippetAction -> "create_snippet"
    UpdateSnippetAction -> "update_snippet"
    DeleteSnippetAction -> "delete_snippet"
    SendLoginTokenAction -> "send_login_token"
    LoginAction -> "login"
  }
}
