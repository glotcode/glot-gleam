import gleam/dynamic/decode

pub type ApiAction {
  RunAction
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
    "Run" -> decode.success(RunAction)
    "GetSnippet" -> decode.success(GetSnippetAction)
    "CreateSnippet" -> decode.success(CreateSnippetAction)
    "UpdateSnippet" -> decode.success(UpdateSnippetAction)
    "DeleteSnippet" -> decode.success(DeleteSnippetAction)
    "SendLoginToken" -> decode.success(SendLoginTokenAction)
    "Login" -> decode.success(LoginAction)
    _ -> decode.failure(RunAction, "ApiAction")
  }
}

pub fn to_string(action: ApiAction) -> String {
  case action {
    RunAction -> "Run"
    GetSnippetAction -> "GetSnippet"
    CreateSnippetAction -> "CreateSnippet"
    UpdateSnippetAction -> "UpdateSnippet"
    DeleteSnippetAction -> "DeleteSnippet"
    SendLoginTokenAction -> "SendLoginToken"
    LoginAction -> "Login"
  }
}

pub fn to_db_string(action: ApiAction) -> String {
  case action {
    RunAction -> "run_snippet_action"
    GetSnippetAction -> "get_snippet_action"
    CreateSnippetAction -> "create_snippet_action"
    UpdateSnippetAction -> "update_snippet_action"
    DeleteSnippetAction -> "delete_snippet_action"
    SendLoginTokenAction -> "send_login_token_action"
    LoginAction -> "login_action"
  }
}
