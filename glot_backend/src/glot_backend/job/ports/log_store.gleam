import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/job/model/log_entry
import glot_backend/system/effect/error/db_error
import glot_core/admin/job_log_dto
import glot_core/job_log_model
import youid/uuid.{type Uuid}

pub type LogStore {
  LogStore(
    insert: fn(log_entry.LogEntry) -> Result(Nil, db_error.DbCommandError),
    list: fn(job_log_dto.ListJobLogsRequest) ->
      Result(List(job_log_model.JobLog), db_error.DbQueryError),
    get: fn(Uuid) ->
      Result(option.Option(job_log_model.JobLog), db_error.DbQueryError),
    delete_before: fn(Timestamp) -> Result(Nil, db_error.DbCommandError),
  )
}
