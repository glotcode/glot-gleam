pub type DbQueryError {
  DbQueryError(message: String)
}

pub type DbCommandError {
  DbCommandError(message: String)
}

pub type DbTransactionError {
  DbTransactionError(message: String)
}

pub fn query_to_string(err: DbQueryError) -> String {
  let DbQueryError(message: message) = err
  "query_error:" <> message
}

pub fn command_to_string(err: DbCommandError) -> String {
  let DbCommandError(message: message) = err
  "command_error:" <> message
}

pub fn transaction_to_string(err: DbTransactionError) -> String {
  let DbTransactionError(message: message) = err
  "transaction_error:" <> message
}
