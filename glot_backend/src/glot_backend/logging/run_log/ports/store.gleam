import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import glot_backend/system/effect/error/db_error
import glot_core/admin/run_log_dto
import glot_core/run_log_model.{type RunLog}
import youid/uuid.{type Uuid}

pub type Store {
  Store(
    create: fn(RunLog) -> Result(Nil, db_error.DbCommandError),
    list: fn(run_log_dto.ListRunLogsRequest) ->
      Result(List(RunLog), db_error.DbQueryError),
    get: fn(Uuid) -> Result(Option(RunLog), db_error.DbQueryError),
    delete_before: fn(Timestamp) -> Result(Nil, db_error.DbCommandError),
  )
}
