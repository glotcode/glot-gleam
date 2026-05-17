import glot_backend/effect/error/db_error
import glot_core/job/job_model

pub type DatabaseOperation {
  QueryOperation
  CommandOperation
  TransactionOperation
}

pub type Retryability {
  Retryable
  NonRetryable
}

pub type EmailError {
  EmailTemplateMissing(name: String)
  EmailTemplateRenderFailed(message: String)
  EmailDeliveryFailed(detail: String, retryability: Retryability)
}

pub type InfraError {
  DatabaseError(operation: DatabaseOperation, message: String)
  RunRequestClientError(message: String)
  RunRequestServerError
  EmailError(EmailError)
  JobTimeoutExceeded
  JobPayloadMissing(job_type: job_model.JobType)
}

pub fn status(err: InfraError) -> Int {
  case err {
    RunRequestClientError(_) -> 400
    _ -> 500
  }
}

pub fn code(err: InfraError) -> String {
  case err {
    DatabaseError(operation, _) ->
      case operation {
        QueryOperation -> "database_query_error"
        CommandOperation -> "database_command_error"
        TransactionOperation -> "database_transaction_error"
      }
    RunRequestClientError(_) -> "run_request_client_error"
    RunRequestServerError -> "run_request_server_error"
    EmailError(_) -> "send_email_error"
    JobTimeoutExceeded -> "job_timeout_exceeded"
    JobPayloadMissing(_) -> "job_payload_missing"
  }
}

pub fn message(err: InfraError) -> String {
  case err {
    DatabaseError(operation, _) ->
      case operation {
        QueryOperation -> "Failed to query data"
        CommandOperation -> "Failed to run command"
        TransactionOperation -> "Transaction failed"
      }
    RunRequestClientError(message) -> message
    RunRequestServerError -> "Failed to run code"
    EmailError(_) -> "Failed to send email"
    JobTimeoutExceeded -> "Job timed out"
    JobPayloadMissing(_) -> "Job payload missing"
  }
}

pub fn to_string(err: InfraError) -> String {
  case err {
    DatabaseError(operation, message) ->
      case operation {
        QueryOperation -> "query_error:" <> message
        CommandOperation -> "command_error:" <> message
        TransactionOperation -> "transaction_error:" <> message
      }
    RunRequestClientError(message) -> "run_error_client:" <> message
    RunRequestServerError -> "run_error_server"
    EmailError(email_error) ->
      case email_error {
        EmailTemplateMissing(name) -> "send_email_missing_template:" <> name
        EmailTemplateRenderFailed(message) ->
          "send_email_render_failed:" <> message
        EmailDeliveryFailed(detail, _) ->
          "send_email_delivery_failed:" <> detail
      }
    JobTimeoutExceeded -> "job_timeout_exceeded"
    JobPayloadMissing(job_type) ->
      "job_payload_missing:" <> job_model.job_type_to_string(job_type)
  }
}

pub fn from_query_error(err: db_error.DbQueryError) -> InfraError {
  let db_error.DbQueryError(message: message) = err
  DatabaseError(QueryOperation, message)
}

pub fn from_command_error(err: db_error.DbCommandError) -> InfraError {
  let db_error.DbCommandError(message: message) = err
  DatabaseError(CommandOperation, message)
}

pub fn from_transaction_error(err: db_error.DbTransactionError) -> InfraError {
  let db_error.DbTransactionError(message: message) = err
  DatabaseError(TransactionOperation, message)
}

pub fn retryable(err: InfraError) -> Bool {
  case err {
    DatabaseError(_, _) -> True
    RunRequestClientError(_) -> False
    RunRequestServerError -> True
    EmailError(email_error) -> email_error_retryable(email_error)
    JobTimeoutExceeded -> True
    JobPayloadMissing(_) -> False
  }
}

fn email_error_retryable(err: EmailError) -> Bool {
  case err {
    EmailTemplateMissing(_) -> False
    EmailTemplateRenderFailed(_) -> False
    EmailDeliveryFailed(_, retryability) ->
      case retryability {
        Retryable -> True
        NonRetryable -> False
      }
  }
}
