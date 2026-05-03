import gleam/dynamic/decode
import gleam/json
import gleam/option

pub type ApiAction {
  TrackPageviewAction
  RunAction
  GetLanguageVersionAction
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
  case from_string(action) {
    option.Some(action) -> decode.success(action)
    option.None -> decode.failure(RunAction, "ApiAction")
  }
}

pub fn encode(action: ApiAction) -> json.Json {
  action |> to_string |> json.string
}

pub fn to_string(action: ApiAction) -> String {
  case action {
    TrackPageviewAction -> "track_pageview"
    RunAction -> "run"
    GetLanguageVersionAction -> "get_language_version"
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

pub fn from_string(action: String) -> option.Option(ApiAction) {
  case action {
    "track_pageview" -> option.Some(TrackPageviewAction)
    "run" -> option.Some(RunAction)
    "get_language_version" -> option.Some(GetLanguageVersionAction)
    "get_session" -> option.Some(GetSessionAction)
    "logout" -> option.Some(LogoutAction)
    "get_account" -> option.Some(GetAccountAction)
    "update_account" -> option.Some(UpdateAccountAction)
    "schedule_delete_account" -> option.Some(ScheduleDeleteAccountAction)
    "cancel_delete_account" -> option.Some(CancelDeleteAccountAction)
    "get_snippet" -> option.Some(GetSnippetAction)
    "list_public_snippets" -> option.Some(ListPublicSnippetsAction)
    "list_session_snippets" -> option.Some(ListSessionSnippetsAction)
    "create_snippet" -> option.Some(CreateSnippetAction)
    "update_snippet" -> option.Some(UpdateSnippetAction)
    "delete_snippet" -> option.Some(DeleteSnippetAction)
    "send_login_token" -> option.Some(SendLoginTokenAction)
    "login" -> option.Some(LoginAction)
    _ -> option.None
  }
}
