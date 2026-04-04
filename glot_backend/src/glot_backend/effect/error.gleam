import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/string
import glot_core/rate_limit.{type RateLimit}

pub type DbQueryError {
  DbQueryError(message: String)
}

pub type DbCommandError {
  DbCommandError(message: String)
}

pub type DbTransactionError {
  DbTransactionError(message: String)
}

pub type RunRequestError {
  PublicRunRequestError(message: String)
  InternalRunRequestError(message: String)
}

pub type LoginError {
  InvalidTokenError
  TokenUsedError
  TokenExpiredError
}

pub type SendEmailError {
  PublicSendEmailError(message: String)
  InternalSendEmailError(message: String)
}

pub type SessionError {
  MissingSessionTokenError
  SessionNotFoundError
  SessionExpiredError
}

pub type ClientInfoError {
  MissingUserIdAndIpError
}

pub type AuthorizationError {
  NotOwnerError
}

pub type Error {
  JsonParseError(json.DecodeError)
  DecodeError(List(decode.DecodeError))
  EmailInvalidError(String)
  TooManyRequestsError(count: Int, rate_limit: RateLimit)
  QueryError(DbQueryError)
  CommandError(DbCommandError)
  TransactionError(DbTransactionError)
  RunError(RunRequestError)
  LoginError(LoginError)
  SendEmailError(SendEmailError)
  SessionError(SessionError)
  ClientInfoError(ClientInfoError)
  AuthorizationError(AuthorizationError)
}

pub fn to_string(err: Error) -> String {
  case err {
    JsonParseError(error) -> "parse_error:" <> string.inspect(error)
    DecodeError(errors) -> "decode_error:" <> string.inspect(errors)
    EmailInvalidError(message) -> "email_invalid:" <> message
    TooManyRequestsError(count, _) ->
      "too_many_requests:" <> int.to_string(count)
    QueryError(DbQueryError(message: message)) -> "query_error:" <> message
    CommandError(DbCommandError(message: message)) ->
      "command_error:" <> message
    TransactionError(DbTransactionError(message: message)) ->
      "transaction_error:" <> message
    LoginError(InvalidTokenError) -> "login_error:invalid_token"
    LoginError(TokenUsedError) -> "login_error:token_used"
    LoginError(TokenExpiredError) -> "login_error:token_expired"
    SendEmailError(PublicSendEmailError(message: message)) ->
      "send_email_public:" <> message
    SendEmailError(InternalSendEmailError(message: message)) ->
      "send_email_internal:" <> message
    SessionError(MissingSessionTokenError) ->
      "session_error:missing_session_token"
    SessionError(SessionNotFoundError) -> "session_error:session_not_found"
    SessionError(SessionExpiredError) -> "session_error:session_expired"
    ClientInfoError(MissingUserIdAndIpError) ->
      "client_info_error:missing_user_id_and_ip"
    AuthorizationError(NotOwnerError) -> "authorization_error:not_owner"
    RunError(PublicRunRequestError(message: message)) ->
      "run_error_public:" <> message
    RunError(InternalRunRequestError(message: message)) ->
      "run_error_internal:" <> message
  }
}
