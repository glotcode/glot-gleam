import gleam/dynamic/decode
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/time/timestamp
import glot_backend/effect/error
import glot_backend/helpers/db_helpers
import glot_backend/sql
import glot_core/admin/api_log_dto
import glot_core/admin/job_log_dto
import glot_core/api_log_model
import glot_core/helpers/uuid_helpers
import glot_core/job_log_model
import glot_core/pagination_model
import pog
import youid/uuid

pub type AdminLogHandlers {
  AdminLogHandlers(
    list_api_logs: fn(api_log_dto.ListApiLogsRequest) ->
      Result(List(api_log_model.ApiLogSummary), error.DbQueryError),
    get_api_log: fn(uuid.Uuid) ->
      Result(option.Option(api_log_model.ApiLogDetail), error.DbQueryError),
    list_job_logs: fn(job_log_dto.ListJobLogsRequest) ->
      Result(List(job_log_model.JobLog), error.DbQueryError),
    get_job_log: fn(uuid.Uuid) ->
      Result(option.Option(job_log_model.JobLog), error.DbQueryError),
  )
}

pub fn new(db: pog.Connection) -> AdminLogHandlers {
  AdminLogHandlers(
    list_api_logs: fn(request) { list_api_logs(db, request) },
    get_api_log: fn(request_id) { get_api_log(db, request_id) },
    list_job_logs: fn(request) { list_job_logs(db, request) },
    get_job_log: fn(id) { get_job_log(db, id) },
  )
}

pub fn list_api_logs(
  db: pog.Connection,
  request: api_log_dto.ListApiLogsRequest,
) -> Result(List(api_log_model.ApiLogSummary), error.DbQueryError) {
  let has_errors_only = case request.error_filter {
    api_log_dto.OnlyApiLogsWithErrors -> True
    api_log_dto.AllApiLogs -> False
  }

  case request.pagination {
    pagination_model.BeforePage(cursor, limit) ->
      api_log_model.decode_cursor(cursor)
      |> result.map_error(error.DbQueryError)
      |> result.try(fn(decoded_cursor) {
        db_helpers.query(
          db,
          sql.list_admin_api_logs_before(
            filter_by_request_id: option.is_some(request.request_id),
            request_id: request_id_param(request.request_id),
            has_errors_only: has_errors_only,
            has_before_cursor: True,
            before_created_at: decoded_cursor.0,
            before_request_id: uuid.to_bit_array(decoded_cursor.1),
            page_limit: limit,
          ),
          fn(err) { error.DbQueryError(string.inspect(err)) },
        )
        |> result.map(fn(returned) {
          returned.rows
          |> list.map(get_api_log_summary_from_before_row)
          |> list.reverse
        })
      })
    pagination_model.InitialPage(limit) | pagination_model.AfterPage(_, limit) -> {
      let decoded_cursor = case request.pagination {
        pagination_model.AfterPage(cursor, _) ->
          api_log_model.decode_cursor(cursor)
          |> result.map(option.Some)
          |> result.map_error(error.DbQueryError)
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
            after_request_id: cursor_request_id(cursor),
            page_limit: limit,
          ),
          fn(err) { error.DbQueryError(string.inspect(err)) },
        )
        |> result.map(fn(returned) {
          list.map(returned.rows, get_api_log_summary_from_after_row)
        })
      })
    }
  }
}

pub fn get_api_log(
  db: pog.Connection,
  request_id: uuid.Uuid,
) -> Result(option.Option(api_log_model.ApiLogDetail), error.DbQueryError) {
  use returned <- result.try(
    db_helpers.query(
      db,
      sql.get_admin_api_log(request_id: uuid.to_bit_array(request_id)),
      fn(err) { error.DbQueryError(string.inspect(err)) },
    ),
  )

  case returned.rows {
    [] -> Ok(option.None)
    [row] -> Ok(option.Some(get_api_log_detail_from_row(row)))
    _ -> Error(error.DbQueryError("Expected at most one api log row"))
  }
}

pub fn list_job_logs(
  db: pog.Connection,
  request: job_log_dto.ListJobLogsRequest,
) -> Result(List(job_log_model.JobLog), error.DbQueryError) {
  let has_errors_only = case request.error_filter {
    job_log_dto.OnlyJobLogsWithErrors -> True
    job_log_dto.AllJobLogs -> False
  }

  case request.pagination {
    pagination_model.BeforePage(cursor, limit) ->
      job_log_model.decode_cursor(cursor)
      |> result.map_error(error.DbQueryError)
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
          fn(err) { error.DbQueryError(string.inspect(err)) },
        )
        |> result.map(fn(returned) {
          returned.rows
          |> list.map(get_job_log_from_before_row)
          |> list.reverse
        })
      })
    pagination_model.InitialPage(limit) | pagination_model.AfterPage(_, limit) -> {
      let decoded_cursor = case request.pagination {
        pagination_model.AfterPage(cursor, _) ->
          job_log_model.decode_cursor(cursor)
          |> result.map(option.Some)
          |> result.map_error(error.DbQueryError)
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
          fn(err) { error.DbQueryError(string.inspect(err)) },
        )
        |> result.map(fn(returned) {
          list.map(returned.rows, get_job_log_from_after_row)
        })
      })
    }
  }
}

pub fn get_job_log(
  db: pog.Connection,
  id: uuid.Uuid,
) -> Result(option.Option(job_log_model.JobLog), error.DbQueryError) {
  use returned <- result.try(
    db_helpers.query(
      db,
      sql.get_admin_job_log(id: uuid.to_bit_array(id)),
      fn(err) { error.DbQueryError(string.inspect(err)) },
    ),
  )

  case returned.rows {
    [] -> Ok(option.None)
    [row] -> Ok(option.Some(get_job_log_from_detail_row(row)))
    _ -> Error(error.DbQueryError("Expected at most one job log row"))
  }
}

fn get_api_log_summary_from_after_row(
  row: sql.ListAdminApiLogsAfter,
) -> api_log_model.ApiLogSummary {
  api_log_summary(
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
    request_id: uuid_helpers.from_bit_array(row.request_id),
    created_at: row.created_at,
    action: row.action,
    duration_ns: row.duration_ns,
    has_error: row.has_error,
  )
}

fn api_log_summary(
  request_id request_id: uuid.Uuid,
  created_at created_at: timestamp.Timestamp,
  action action: String,
  duration_ns duration_ns: Int,
  has_error has_error: Bool,
) -> api_log_model.ApiLogSummary {
  api_log_model.ApiLogSummary(
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

fn get_job_log_from_detail_row(row: sql.GetAdminJobLog) -> job_log_model.JobLog {
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
  value: option.Option(#(timestamp.Timestamp, uuid.Uuid)),
) -> timestamp.Timestamp {
  case value {
    option.Some(cursor) -> cursor.0
    option.None -> timestamp.from_unix_seconds_and_nanoseconds(0, 0)
  }
}

fn cursor_request_id(
  value: option.Option(#(timestamp.Timestamp, uuid.Uuid)),
) -> BitArray {
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
