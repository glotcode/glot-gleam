pub type RunRequestError {
  ClientRunRequestError(message: String)
  ServerRunRequestError
}

pub fn to_string(err: RunRequestError) -> String {
  case err {
    ClientRunRequestError(message: message) -> "run_error_client:" <> message
    ServerRunRequestError -> "run_error_server"
  }
}
