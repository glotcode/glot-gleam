import gleam/dynamic/decode
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp, from_unix_seconds_and_nanoseconds}
import glot_backend/logging/api_log/ports/store as api_log_store
import glot_backend/sql
import glot_backend/system/database as db_helpers
import glot_backend/system/effect/error/db_error
import glot_core/admin/api_log_dto
import glot_core/api_log_model
import glot_core/helpers/uuid_helpers
import glot_core/pagination_model
import glot_core/validation_error
import youid/uuid

pub fn new(db: db_helpers.Db) -> api_log_store.Store {
  api_log_store.Store(
    list: fn(request) { list_api_logs(db, request) },
    get: fn(id) { get_api_log(db, id) },
    delete_before: fn(before) { delete_before(db, before) },
  )
}

pub fn delete_before(
  db: db_helpers.Db,
  before: Timestamp,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(db, sql.delete_api_log_before(before), to_error)
  |> result.map(fn(_) { Nil })
}

pub fn list_api_logs(
  db: db_helpers.Db,
  request: api_log_dto.ListApiLogsRequest,
) -> Result(List(api_log_model.ApiLogSummary), db_error.DbQueryError) {
  let has_errors_only = case request.error_filter {
    api_log_dto.OnlyApiLogsWithErrors -> True
    api_log_dto.AllApiLogs -> False
  }

  case request.pagination {
    pagination_model.BeforePage(cursor, limit) ->
      api_log_model.decode_cursor(cursor)
      |> result.map_error(validation_error.to_string)
      |> result.map_error(db_error.DbQueryError)
      |> result.try(fn(decoded_cursor) {
        db_helpers.query(
          db,
          sql.list_admin_api_logs_before(
            filter_by_request_id: option.is_some(request.request_id),
            request_id: request_id_param(request.request_id),
            has_errors_only: has_errors_only,
            has_before_cursor: True,
            before_created_at: decoded_cursor.0,
            before_id: uuid.to_bit_array(decoded_cursor.1),
            page_limit: limit,
          ),
          fn(err) { db_error.DbQueryError(string.inspect(err)) },
        )
        |> result.map(fn(returned) {
          returned.rows
          |> list.map(get_api_log_summary_from_before_row)
          |> list.reverse
        })
      })
    pagination_model.InitialPage(limit)
    | pagination_model.AfterPage(_, limit) -> {
      let decoded_cursor = case request.pagination {
        pagination_model.AfterPage(cursor, _) ->
          api_log_model.decode_cursor(cursor)
          |> result.map(option.Some)
          |> result.map_error(validation_error.to_string)
          |> result.map_error(db_error.DbQueryError)
        pagination_model.InitialPage(_) -> Ok(option.None)
        pagination_model.BeforePage(_, _) -> Ok(option.None)
      }

      decoded_cursor
      |> result.try(fn(cursor) {
        db_helpers.query(
          db,
          sql.list_admin_api_logs_after(
            filter_by_request_id: option.is_some(request.request_id),
            request_id: request_id_param(request.request_id),
            has_errors_only: has_errors_only,
            has_after_cursor: option.is_some(cursor),
            after_created_at: cursor_timestamp(cursor),
            after_id: cursor_id(cursor),
            page_limit: limit,
          ),
          fn(err) { db_error.DbQueryError(string.inspect(err)) },
        )
        |> result.map(fn(returned) {
          list.map(returned.rows, get_api_log_summary_from_after_row)
        })
      })
    }
  }
}

pub fn get_api_log(
  db: db_helpers.Db,
  id: uuid.Uuid,
) -> Result(option.Option(api_log_model.ApiLogDetail), db_error.DbQueryError) {
  use returned <- result.try(
    db_helpers.query(
      db,
      sql.get_admin_api_log(id: uuid.to_bit_array(id)),
      fn(err) { db_error.DbQueryError(string.inspect(err)) },
    ),
  )

  case returned.rows {
    [] -> Ok(option.None)
    [row] -> Ok(option.Some(get_api_log_detail_from_row(row)))
    _ -> Error(db_error.DbQueryError("Expected at most one api log row"))
  }
}

fn get_api_log_summary_from_after_row(
  row: sql.ListAdminApiLogsAfter,
) -> api_log_model.ApiLogSummary {
  api_log_summary(
    id: uuid_helpers.from_bit_array(row.id),
    request_id: uuid_helpers.from_bit_array(row.request_id),
    created_at: row.created_at,
    action: row.action,
    duration_ns: row.duration_ns,
    has_error: row.has_error,
  )
}

fn get_api_log_summary_from_before_row(
  row: sql.ListAdminApiLogsBefore,
) -> api_log_model.ApiLogSummary {
  api_log_summary(
    id: uuid_helpers.from_bit_array(row.id),
    request_id: uuid_helpers.from_bit_array(row.request_id),
    created_at: row.created_at,
    action: row.action,
    duration_ns: row.duration_ns,
    has_error: row.has_error,
  )
}

fn api_log_summary(
  id id: uuid.Uuid,
  request_id request_id: uuid.Uuid,
  created_at created_at: Timestamp,
  action action: String,
  duration_ns duration_ns: Int,
  has_error has_error: Bool,
) -> api_log_model.ApiLogSummary {
  api_log_model.ApiLogSummary(
    id: id,
    request_id: request_id,
    created_at: created_at,
    action: action,
    duration_ns: duration_ns,
    has_error: has_error,
  )
}

fn get_api_log_detail_from_row(
  row: sql.GetAdminApiLog,
) -> api_log_model.ApiLogDetail {
  api_log_model.ApiLogDetail(
    id: uuid_helpers.from_bit_array(row.id),
    request_id: uuid_helpers.from_bit_array(row.request_id),
    created_at: row.created_at,
    log: api_log_model.ApiLogEntry(
      created_at: row.created_at,
      action: row.action,
      body_bytes: row.body_bytes,
      duration_ns: row.duration_ns,
      ip: row.ip,
      user_agent: row.user_agent,
      info: dynamic_string_to_option(row.info),
      warnings: dynamic_string_to_option(row.warnings),
      debug: dynamic_string_to_option(row.debug),
      error: dynamic_string_to_option(row.error),
      effects: dynamic_string_to_option(row.effects),
    ),
  )
}

fn request_id_param(value: option.Option(uuid.Uuid)) -> BitArray {
  case value {
    option.Some(id) -> uuid.to_bit_array(id)
    option.None -> uuid.to_bit_array(uuid.nil)
  }
}

fn cursor_timestamp(
  value: option.Option(#(Timestamp, uuid.Uuid)),
) -> Timestamp {
  case value {
    option.Some(cursor) -> cursor.0
    option.None -> from_unix_seconds_and_nanoseconds(0, 0)
  }
}

fn cursor_id(value: option.Option(#(Timestamp, uuid.Uuid))) -> BitArray {
  case value {
    option.Some(cursor) -> uuid.to_bit_array(cursor.1)
    option.None -> uuid.to_bit_array(uuid.nil)
  }
}

fn empty_string_to_option(value: String) -> option.Option(String) {
  case value == "" {
    True -> option.None
    False -> option.Some(value)
  }
}

fn dynamic_string_to_option(
  value: option.Option(decode.Dynamic),
) -> option.Option(String) {
  case value {
    option.Some(value) ->
      case decode.run(value, decode.string) {
        Ok(text) -> empty_string_to_option(text)
        Error(_) -> option.None
      }
    option.None -> option.None
  }
}
