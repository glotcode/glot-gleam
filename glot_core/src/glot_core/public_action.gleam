import gleam/dynamic/decode
import gleam/json
import gleam/option

pub type PublicAction {
  TrackPageviewAction
  RunAction
  GetLanguageVersionAction
  GetSessionAction
  RefreshSessionAction
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

pub fn list() -> List(PublicAction) {
  [
    TrackPageviewAction,
    RunAction,
    GetLanguageVersionAction,
    GetSessionAction,
    RefreshSessionAction,
    LogoutAction,
    GetAccountAction,
    UpdateAccountAction,
    ScheduleDeleteAccountAction,
    CancelDeleteAccountAction,
    GetSnippetAction,
    ListPublicSnippetsAction,
    ListSessionSnippetsAction,
    CreateSnippetAction,
    UpdateSnippetAction,
    DeleteSnippetAction,
    SendLoginTokenAction,
    LoginAction,
  ]
}

pub fn decoder() -> decode.Decoder(PublicAction) {
  use action <- decode.then(decode.string)
  case from_string(action) {
    option.Some(action) -> decode.success(action)
    option.None -> decode.failure(RunAction, "PublicAction")
  }
}

pub fn encode(action: PublicAction) -> json.Json {
  action |> to_string |> json.string
}

pub fn to_string(action: PublicAction) -> String {
  case action {
    TrackPageviewAction -> "track_pageview"
    RunAction -> "run"
    GetLanguageVersionAction -> "get_language_version"
    GetSessionAction -> "get_session"
    RefreshSessionAction -> "refresh_session"
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

pub fn from_string(action: String) -> option.Option(PublicAction) {
  case action {
    "track_pageview" -> option.Some(TrackPageviewAction)
    "run" -> option.Some(RunAction)
    "get_language_version" -> option.Some(GetLanguageVersionAction)
    "get_session" -> option.Some(GetSessionAction)
    "refresh_session" -> option.Some(RefreshSessionAction)
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
