import gleam/dynamic/decode

pub type ApiAction {
  RunAction
  CreateSnippetAction
  UpdateSnippetAction
  SendLoginTokenAction
  LoginAction
}

pub fn decoder() -> decode.Decoder(ApiAction) {
  use action <- decode.then(decode.string)
  case action {
    "Run" -> decode.success(RunAction)
    "CreateSnippet" -> decode.success(CreateSnippetAction)
    "UpdateSnippet" -> decode.success(UpdateSnippetAction)
    "SendLoginToken" -> decode.success(SendLoginTokenAction)
    "Login" -> decode.success(LoginAction)
    _ -> decode.failure(RunAction, "ApiAction")
  }
}

pub fn to_string(action: ApiAction) -> String {
  case action {
    RunAction -> "Run"
    CreateSnippetAction -> "CreateSnippet"
    UpdateSnippetAction -> "UpdateSnippet"
    SendLoginTokenAction -> "SendLoginToken"
    LoginAction -> "Login"
  }
}

pub fn to_db_string(action: ApiAction) -> String {
  case action {
    RunAction -> "run_snippet_action"
    CreateSnippetAction -> "create_snippet_action"
    UpdateSnippetAction -> "update_snippet_action"
    SendLoginTokenAction -> "send_login_token_action"
    LoginAction -> "login_action"
  }
}
