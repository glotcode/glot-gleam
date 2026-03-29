import gleam/dynamic/decode

pub type ApiAction {
  RunAction
  SnippetCreateAction
  SendLoginTokenAction
  LoginAction
}

pub fn decoder() -> decode.Decoder(ApiAction) {
  use action <- decode.then(decode.string)
  case action {
    "Run" -> decode.success(RunAction)
    "SnippetCreate" -> decode.success(SnippetCreateAction)
    "SendLoginToken" -> decode.success(SendLoginTokenAction)
    "Login" -> decode.success(LoginAction)
    _ -> decode.failure(RunAction, "ApiAction")
  }
}

pub fn to_string(action: ApiAction) -> String {
  case action {
    RunAction -> "Run"
    SnippetCreateAction -> "SnippetCreate"
    SendLoginTokenAction -> "SendLoginToken"
    LoginAction -> "Login"
  }
}

pub fn to_db_string(action: ApiAction) -> String {
  case action {
    RunAction -> "run_snippet_action"
    SnippetCreateAction -> "snippet_create_action"
    SendLoginTokenAction -> "send_login_token_action"
    LoginAction -> "login_action"
  }
}
