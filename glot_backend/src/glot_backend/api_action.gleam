import gleam/dynamic/decode

pub type ApiAction {
  RunAction
  SendLoginTokenAction
}

pub fn decoder() -> decode.Decoder(ApiAction) {
  use action <- decode.then(decode.string)
  case action {
    "Run" -> decode.success(RunAction)
    "SendLoginToken" -> decode.success(SendLoginTokenAction)
    _ -> decode.failure(RunAction, "ApiAction")
  }
}

pub fn to_string(action: ApiAction) -> String {
  case action {
    RunAction -> "Run"
    SendLoginTokenAction -> "SendLoginToken"
  }
}

pub fn to_db_string(action: ApiAction) -> String {
  case action {
    RunAction -> "run_snippet_action"
    SendLoginTokenAction -> "send_login_token_action"
  }
}
