import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import glot_backend/system/effect/error/db_error
import glot_core/admin/api_log_dto
import glot_core/api_log_model.{type ApiLogDetail, type ApiLogSummary}
import youid/uuid.{type Uuid}

pub type Store {
  Store(
    list: fn(api_log_dto.ListApiLogsRequest) ->
      Result(List(ApiLogSummary), db_error.DbQueryError),
    get: fn(Uuid) -> Result(Option(ApiLogDetail), db_error.DbQueryError),
    delete_before: fn(Timestamp) -> Result(Nil, db_error.DbCommandError),
  )
}
