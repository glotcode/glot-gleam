import gleam/dynamic/decode
import gleam/json

pub type ApiAction {
  RunAction
  GetSessionAction
  GetAccountAction
  UpdateAccountAction
  GetSnippetAction
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
    "get_account" -> decode.success(GetAccountAction)
    "update_account" -> decode.success(UpdateAccountAction)
    "get_snippet" -> decode.success(GetSnippetAction)
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
    GetAccountAction -> "get_account"
    UpdateAccountAction -> "update_account"
    GetSnippetAction -> "get_snippet"
    CreateSnippetAction -> "create_snippet"
    UpdateSnippetAction -> "update_snippet"
    DeleteSnippetAction -> "delete_snippet"
    SendLoginTokenAction -> "send_login_token"
    LoginAction -> "login"
  }
}
