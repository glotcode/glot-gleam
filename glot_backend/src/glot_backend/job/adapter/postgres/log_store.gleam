import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp, from_unix_seconds_and_nanoseconds}
import glot_backend/job/model/log_entry
import glot_backend/job/ports/log_store
import glot_backend/sql
import glot_backend/system/database as db_helpers
import glot_backend/system/effect/effect_trace
import glot_backend/system/effect/error
import glot_backend/system/effect/error/db_error
import glot_backend/system/effect/log
import glot_core/admin/job_log_dto
import glot_core/helpers/dict_helpers
import glot_core/helpers/list_helpers
import glot_core/helpers/uuid_helpers
import glot_core/job/job_model
import glot_core/job_log_model
import glot_core/pagination_model
import glot_core/validation_error
import youid/uuid

pub fn new(db: db_helpers.Db) -> log_store.LogStore {
  log_store.LogStore(
    insert: fn(entry) { insert(db, entry) },
    list: fn(request) { list_job_logs(db, request) },
    get: fn(id) { get_job_log(db, id) },
    delete_before: fn(before) { delete_before(db, before) },
  )
}

pub fn insert(
  db: db_helpers.Db,
  entry: log_entry.LogEntry,
) -> Result(Nil, db_error.DbCommandError) {
  let query =
    sql.insert_job_log(
      id: uuid.to_bit_array(entry.id),
      request_id: entry.request_id |> option.map(uuid.to_bit_array),
      job_id: uuid.to_bit_array(entry.job_id),
      job_type: job_model.job_type_to_string(entry.job_type),
      attempt: entry.attempt,
      created_at: entry.created_at,
      duration_ns: entry.duration_ns,
      info: entry.info
        |> dict_helpers.non_empty_dict
        |> option.map(log.encode_fields)
        |> option.map(json.to_string),
      warnings: entry.warnings
        |> dict_helpers.non_empty_dict
        |> option.map(log.encode_fields)
        |> option.map(json.to_string),
      debug: entry.debug
        |> dict_helpers.non_empty_dict
        |> option.map(log.encode_fields)
        |> option.map(json.to_string),
      error: entry.error
        |> option.map(encode_error)
        |> option.map(json.to_string),
      effects: entry.effects
        |> list_helpers.non_empty_list
        |> option.map(effect_trace.encode_effect_measurements)
        |> option.map(json.to_string),
    )

  db_helpers.execute(db, query, fn(err) {
    db_error.DbCommandError(string.inspect(err))
  })
  |> result.map(fn(_) { Nil })
}

fn encode_error(err: error.Error) -> json.Json {
  json.object([#("message", json.string(error.to_string(err)))])
}

pub fn delete_before(
  db: db_helpers.Db,
  before: Timestamp,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(db, sql.delete_job_log_before(before), to_error)
  |> result.map(fn(_) { Nil })
}

pub fn list_job_logs(
  db: db_helpers.Db,
  request: job_log_dto.ListJobLogsRequest,
) -> Result(List(job_log_model.JobLog), db_error.DbQueryError) {
  let has_errors_only = case request.error_filter {
    job_log_dto.OnlyJobLogsWithErrors -> True
    job_log_dto.AllJobLogs -> False
  }

  case request.pagination {
    pagination_model.BeforePage(cursor, limit) ->
      job_log_model.decode_cursor(cursor)
      |> result.map_error(validation_error.to_string)
      |> result.map_error(db_error.DbQueryError)
      |> result.try(fn(decoded_cursor) {
        db_helpers.query(
          db,
          sql.list_admin_job_logs_before(
            filter_by_request_id: option.is_some(request.request_id),
            request_id: request_id_param(request.request_id),
            filter_by_job_id: option.is_some(request.job_id),
            job_id: request_id_param(request.job_id),
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
          |> list.map(get_job_log_from_before_row)
          |> list.reverse
        })
      })
    pagination_model.InitialPage(limit)
    | pagination_model.AfterPage(_, limit) -> {
      let decoded_cursor = case request.pagination {
        pagination_model.AfterPage(cursor, _) ->
          job_log_model.decode_cursor(cursor)
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
          sql.list_admin_job_logs_after(
            filter_by_request_id: option.is_some(request.request_id),
            request_id: request_id_param(request.request_id),
            filter_by_job_id: option.is_some(request.job_id),
            job_id: request_id_param(request.job_id),
            has_errors_only: has_errors_only,
            has_after_cursor: option.is_some(cursor),
            after_created_at: cursor_timestamp(cursor),
            after_id: cursor_request_id(cursor),
            page_limit: limit,
          ),
          fn(err) { db_error.DbQueryError(string.inspect(err)) },
        )
        |> result.map(fn(returned) {
          list.map(returned.rows, get_job_log_from_after_row)
        })
      })
    }
  }
}

pub fn get_job_log(
  db: db_helpers.Db,
  id: uuid.Uuid,
) -> Result(option.Option(job_log_model.JobLog), db_error.DbQueryError) {
  use returned <- result.try(
    db_helpers.query(
      db,
      sql.get_admin_job_log(id: uuid.to_bit_array(id)),
      fn(err) { db_error.DbQueryError(string.inspect(err)) },
    ),
  )

  case returned.rows {
    [] -> Ok(option.None)
    [row] -> Ok(option.Some(get_job_log_from_detail_row(row)))
    _ -> Error(db_error.DbQueryError("Expected at most one job log row"))
  }
}

fn get_job_log_from_after_row(
  row: sql.ListAdminJobLogsAfter,
) -> job_log_model.JobLog {
  job_log_model.JobLog(
    id: uuid_helpers.from_bit_array(row.id),
    request_id: row.request_id |> option.map(uuid_helpers.from_bit_array),
    job_id: uuid_helpers.from_bit_array(row.job_id),
    job_type: row.job_type,
    attempt: row.attempt,
    created_at: row.created_at,
    duration_ns: row.duration_ns,
    info: dynamic_string_to_option(row.info),
    warnings: dynamic_string_to_option(row.warnings),
    debug: dynamic_string_to_option(row.debug),
    error: dynamic_string_to_option(row.error),
    effects: dynamic_string_to_option(row.effects),
  )
}

fn get_job_log_from_before_row(
  row: sql.ListAdminJobLogsBefore,
) -> job_log_model.JobLog {
  job_log_model.JobLog(
    id: uuid_helpers.from_bit_array(row.id),
    request_id: row.request_id |> option.map(uuid_helpers.from_bit_array),
    job_id: uuid_helpers.from_bit_array(row.job_id),
    job_type: row.job_type,
    attempt: row.attempt,
    created_at: row.created_at,
    duration_ns: row.duration_ns,
    info: dynamic_string_to_option(row.info),
    warnings: dynamic_string_to_option(row.warnings),
    debug: dynamic_string_to_option(row.debug),
    error: dynamic_string_to_option(row.error),
    effects: dynamic_string_to_option(row.effects),
  )
}

fn get_job_log_from_detail_row(
  row: sql.GetAdminJobLog,
) -> job_log_model.JobLog {
  job_log_model.JobLog(
    id: uuid_helpers.from_bit_array(row.id),
    request_id: row.request_id |> option.map(uuid_helpers.from_bit_array),
    job_id: uuid_helpers.from_bit_array(row.job_id),
    job_type: row.job_type,
    attempt: row.attempt,
    created_at: row.created_at,
    duration_ns: row.duration_ns,
    info: dynamic_string_to_option(row.info),
    warnings: dynamic_string_to_option(row.warnings),
    debug: dynamic_string_to_option(row.debug),
    error: dynamic_string_to_option(row.error),
    effects: dynamic_string_to_option(row.effects),
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

fn cursor_request_id(
  value: option.Option(#(Timestamp, uuid.Uuid)),
) -> BitArray {
  cursor_id(value)
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
