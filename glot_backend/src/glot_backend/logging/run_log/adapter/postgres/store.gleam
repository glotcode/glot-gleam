import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp, from_unix_seconds_and_nanoseconds}
import glot_backend/logging/run_log/ports/store as run_log_store
import glot_backend/sql
import glot_backend/system/database as db_helpers
import glot_backend/system/effect/error/db_error
import glot_core/admin/run_log_dto
import glot_core/helpers/uuid_helpers
import glot_core/language
import glot_core/pagination_model
import glot_core/run_log_model
import glot_core/validation_error
import youid/uuid

pub fn new(db: db_helpers.Db) -> run_log_store.Store {
  run_log_store.Store(
    create: fn(run_log) { create_run_log(db, run_log) },
    list: fn(request) { list_run_logs(db, request) },
    get: fn(id) { get_run_log(db, id) },
    delete_before: fn(before) { delete_before(db, before) },
  )
}

pub fn create_run_log(
  db: db_helpers.Db,
  run_log: run_log_model.RunLog,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.insert_run_log(
      id: uuid.to_bit_array(run_log.id),
      request_id: uuid.to_bit_array(run_log.request_id),
      created_at: run_log.created_at,
      session_id: option.map(run_log.session_id, uuid.to_bit_array),
      user_id: option.map(run_log.user_id, uuid.to_bit_array),
      language: language.to_string(run_log.language),
      outcome: run_log_model.run_outcome_to_string(run_log.outcome),
      duration_ns: run_log.duration_ns,
      failure_message: run_log.failure_message,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn delete_before(
  db: db_helpers.Db,
  before: Timestamp,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(db, sql.delete_run_log_before(before), to_error)
  |> result.map(fn(_) { Nil })
}

pub fn list_run_logs(
  db: db_helpers.Db,
  request: run_log_dto.ListRunLogsRequest,
) -> Result(List(run_log_model.RunLog), db_error.DbQueryError) {
  let maybe_outcome = case request.outcome_filter {
    run_log_dto.AllRunLogs -> option.None
    run_log_dto.OnlySuccessfulRunLogs ->
      option.Some(run_log_model.run_outcome_to_string(
        run_log_model.RunSucceeded,
      ))
    run_log_dto.OnlyFailedRunLogs ->
      option.Some(run_log_model.run_outcome_to_string(run_log_model.RunFailed))
  }

  case request.pagination {
    pagination_model.BeforePage(cursor, limit) ->
      run_log_model.decode_cursor(cursor)
      |> result.map_error(validation_error.to_string)
      |> result.map_error(db_error.DbQueryError)
      |> result.try(fn(decoded_cursor) {
        db_helpers.query(
          db,
          sql.list_admin_run_logs_before(
            filter_by_request_id: option.is_some(request.request_id),
            request_id: request_id_param(request.request_id),
            filter_by_session_id: option.is_some(request.session_id),
            session_id: request_id_param(request.session_id),
            filter_by_user_id: option.is_some(request.user_id),
            user_id: request_id_param(request.user_id),
            filter_by_language: option.is_some(request.language),
            language: language_param(request.language),
            filter_by_outcome: option.is_some(maybe_outcome),
            outcome: string_param(maybe_outcome),
            has_before_cursor: True,
            before_created_at: decoded_cursor.0,
            before_id: uuid.to_bit_array(decoded_cursor.1),
            page_limit: limit,
          ),
          fn(err) { db_error.DbQueryError(string.inspect(err)) },
        )
        |> result.try(fn(returned) {
          returned.rows
          |> list.map(get_run_log_from_before_row)
          |> result.all
          |> result.map(list.reverse)
        })
      })
    pagination_model.InitialPage(limit)
    | pagination_model.AfterPage(_, limit) -> {
      let decoded_cursor = case request.pagination {
        pagination_model.AfterPage(cursor, _) ->
          run_log_model.decode_cursor(cursor)
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
          sql.list_admin_run_logs_after(
            filter_by_request_id: option.is_some(request.request_id),
            request_id: request_id_param(request.request_id),
            filter_by_session_id: option.is_some(request.session_id),
            session_id: request_id_param(request.session_id),
            filter_by_user_id: option.is_some(request.user_id),
            user_id: request_id_param(request.user_id),
            filter_by_language: option.is_some(request.language),
            language: language_param(request.language),
            filter_by_outcome: option.is_some(maybe_outcome),
            outcome: string_param(maybe_outcome),
            has_after_cursor: option.is_some(cursor),
            after_created_at: cursor_timestamp(cursor),
            after_id: cursor_id(cursor),
            page_limit: limit,
          ),
          fn(err) { db_error.DbQueryError(string.inspect(err)) },
        )
        |> result.try(fn(returned) {
          returned.rows
          |> list.map(get_run_log_from_after_row)
          |> result.all
        })
      })
    }
  }
}

pub fn get_run_log(
  db: db_helpers.Db,
  id: uuid.Uuid,
) -> Result(option.Option(run_log_model.RunLog), db_error.DbQueryError) {
  use returned <- result.try(
    db_helpers.query(
      db,
      sql.get_admin_run_log(id: uuid.to_bit_array(id)),
      fn(err) { db_error.DbQueryError(string.inspect(err)) },
    ),
  )

  case returned.rows {
    [] -> Ok(option.None)
    [row] -> get_run_log_from_detail_row(row) |> result.map(option.Some)
    _ -> Error(db_error.DbQueryError("Expected at most one run log row"))
  }
}

fn get_run_log_from_after_row(
  row: sql.ListAdminRunLogsAfter,
) -> Result(run_log_model.RunLog, db_error.DbQueryError) {
  run_log_from_row(
    id: row.id,
    request_id: row.request_id,
    created_at: row.created_at,
    session_id: row.session_id,
    user_id: row.user_id,
    language: row.language,
    outcome: row.outcome,
    duration_ns: row.duration_ns,
    failure_message: row.failure_message,
  )
}

fn get_run_log_from_before_row(
  row: sql.ListAdminRunLogsBefore,
) -> Result(run_log_model.RunLog, db_error.DbQueryError) {
  run_log_from_row(
    id: row.id,
    request_id: row.request_id,
    created_at: row.created_at,
    session_id: row.session_id,
    user_id: row.user_id,
    language: row.language,
    outcome: row.outcome,
    duration_ns: row.duration_ns,
    failure_message: row.failure_message,
  )
}

fn get_run_log_from_detail_row(
  row: sql.GetAdminRunLog,
) -> Result(run_log_model.RunLog, db_error.DbQueryError) {
  run_log_from_row(
    id: row.id,
    request_id: row.request_id,
    created_at: row.created_at,
    session_id: row.session_id,
    user_id: row.user_id,
    language: row.language,
    outcome: row.outcome,
    duration_ns: row.duration_ns,
    failure_message: row.failure_message,
  )
}

fn run_log_from_row(
  id id: BitArray,
  request_id request_id: BitArray,
  created_at created_at: Timestamp,
  session_id session_id: option.Option(BitArray),
  user_id user_id: option.Option(BitArray),
  language language_value: String,
  outcome outcome_value: String,
  duration_ns duration_ns: option.Option(Int),
  failure_message failure_message: option.Option(String),
) -> Result(run_log_model.RunLog, db_error.DbQueryError) {
  use parsed_language <- result.try(
    language.from_string(language_value)
    |> option.to_result(db_error.DbQueryError(
      "Invalid run log language: " <> language_value,
    )),
  )
  use parsed_outcome <- result.try(
    run_log_model.run_outcome_from_string(outcome_value)
    |> option.to_result(db_error.DbQueryError(
      "Invalid run log outcome: " <> outcome_value,
    )),
  )

  Ok(run_log_model.RunLog(
    id: uuid_helpers.from_bit_array(id),
    request_id: uuid_helpers.from_bit_array(request_id),
    created_at: created_at,
    session_id: session_id |> option.map(uuid_helpers.from_bit_array),
    user_id: user_id |> option.map(uuid_helpers.from_bit_array),
    language: parsed_language,
    outcome: parsed_outcome,
    duration_ns: duration_ns,
    failure_message: failure_message,
  ))
}

fn request_id_param(value: option.Option(uuid.Uuid)) -> BitArray {
  case value {
    option.Some(id) -> uuid.to_bit_array(id)
    option.None -> uuid.to_bit_array(uuid.nil)
  }
}

fn language_param(value: option.Option(language.Language)) -> String {
  case value {
    option.Some(lang) -> language.to_string(lang)
    option.None -> ""
  }
}

fn string_param(value: option.Option(String)) -> String {
  case value {
    option.Some(text) -> text
    option.None -> ""
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
