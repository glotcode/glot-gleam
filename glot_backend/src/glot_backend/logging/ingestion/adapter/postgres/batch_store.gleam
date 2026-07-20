import gleam/json
import gleam/list
import gleam/result
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp
import glot_backend/logging/api_log/model/entry as api_log_entry
import glot_backend/logging/ingestion/model/batch
import glot_backend/logging/ingestion/ports/batch_store.{type BatchStore}
import glot_backend/logging/page_log/model/entry as page_log_entry
import glot_backend/logging/pageview/model/entry as pageview_entry
import glot_backend/sql
import glot_backend/system/database as db_helpers
import glot_backend/system/effect/effect_trace
import glot_backend/system/effect/error
import glot_backend/system/effect/error/db_error
import glot_backend/system/effect/log
import glot_core/api_action
import glot_core/helpers/dict_helpers
import glot_core/helpers/list_helpers
import pog
import youid/uuid

pub fn new(db: pog.Connection) -> BatchStore {
  batch_store.BatchStore(insert: fn(entries) { insert(db, entries) })
}

pub fn insert(
  db: pog.Connection,
  entries: List(batch.Entry),
) -> Result(Nil, db_error.DbTransactionError) {
  let #(api_entries, page_entries, pageview_entries) =
    split_entries(entries, [], [], [])

  pog.transaction(db, fn(connection) {
    use _ <- result.try(insert_api_logs(connection, api_entries))
    use _ <- result.try(insert_page_logs(connection, page_entries))
    insert_pageview_logs(connection, pageview_entries)
  })
  |> result.map_error(fn(error) {
    db_error.DbTransactionError(string.inspect(error))
  })
}

fn split_entries(
  entries: List(batch.Entry),
  api_entries: List(api_log_entry.Entry),
  page_entries: List(page_log_entry.Entry),
  pageview_entries: List(pageview_entry.Entry),
) -> #(
  List(api_log_entry.Entry),
  List(page_log_entry.Entry),
  List(pageview_entry.Entry),
) {
  case entries {
    [] -> #(
      list.reverse(api_entries),
      list.reverse(page_entries),
      list.reverse(pageview_entries),
    )
    [batch.Api(entry), ..rest] ->
      split_entries(
        rest,
        [entry, ..api_entries],
        page_entries,
        pageview_entries,
      )
    [batch.Page(entry), ..rest] ->
      split_entries(
        rest,
        api_entries,
        [entry, ..page_entries],
        pageview_entries,
      )
    [batch.Pageview(entry), ..rest] ->
      split_entries(rest, api_entries, page_entries, [entry, ..pageview_entries])
  }
}

fn insert_api_logs(
  db: pog.Connection,
  entries: List(api_log_entry.Entry),
) -> Result(Nil, String) {
  case entries {
    [] -> Ok(Nil)
    _ ->
      db_helpers.execute(
        db_helpers.new(db),
        sql.insert_api_log(
          entries: json.array(entries, of: encode_api_log_entry)
          |> json.to_string,
        ),
        string.inspect,
      )
      |> result.map(fn(_) { Nil })
  }
}

fn insert_page_logs(
  db: pog.Connection,
  entries: List(page_log_entry.Entry),
) -> Result(Nil, String) {
  case entries {
    [] -> Ok(Nil)
    _ ->
      db_helpers.execute(
        db_helpers.new(db),
        sql.insert_page_log(
          entries: json.array(entries, of: encode_page_log_entry)
          |> json.to_string,
        ),
        string.inspect,
      )
      |> result.map(fn(_) { Nil })
  }
}

fn insert_pageview_logs(
  db: pog.Connection,
  entries: List(pageview_entry.Entry),
) -> Result(Nil, String) {
  case entries {
    [] -> Ok(Nil)
    _ ->
      db_helpers.execute(
        db_helpers.new(db),
        sql.insert_pageview_log(
          entries: json.array(entries, of: encode_pageview_log_entry)
          |> json.to_string,
        ),
        string.inspect,
      )
      |> result.map(fn(_) { Nil })
  }
}

fn encode_error(value: error.Error) -> json.Json {
  json.object([#("message", json.string(error.to_string(value)))])
}

fn encode_api_log_entry(entry: api_log_entry.Entry) -> json.Json {
  json.object([
    #("id", json.string(uuid.to_string(entry.id))),
    #("request_id", json.string(uuid.to_string(entry.request_id))),
    #(
      "created_at",
      json.string(timestamp.to_rfc3339(entry.created_at, calendar.utc_offset)),
    ),
    #("action", json.string(api_action.to_string(entry.action))),
    #("body_bytes", json.int(entry.body_bytes)),
    #("duration_ns", json.int(entry.duration_ns)),
    #("ip", json.nullable(entry.ip, json.string)),
    #("user_agent", json.nullable(entry.user_agent, json.string)),
    #(
      "info",
      json.nullable(
        entry.info |> dict_helpers.non_empty_dict,
        log.encode_fields,
      ),
    ),
    #(
      "warnings",
      json.nullable(
        entry.warnings |> dict_helpers.non_empty_dict,
        log.encode_fields,
      ),
    ),
    #(
      "debug",
      json.nullable(
        entry.debug |> dict_helpers.non_empty_dict,
        log.encode_fields,
      ),
    ),
    #("error", json.nullable(entry.error, encode_error)),
    #(
      "effects",
      json.nullable(
        entry.effects |> list_helpers.non_empty_list,
        effect_trace.encode_effect_measurements,
      ),
    ),
  ])
}

fn encode_page_log_entry(entry: page_log_entry.Entry) -> json.Json {
  json.object([
    #("id", json.string(uuid.to_string(entry.id))),
    #("request_id", json.string(uuid.to_string(entry.request_id))),
    #(
      "created_at",
      json.string(timestamp.to_rfc3339(entry.created_at, calendar.utc_offset)),
    ),
    #("route", json.string(entry.route)),
    #("path", json.string(entry.path)),
    #("status_code", json.int(entry.status_code)),
    #("render_mode", json.string(entry.render_mode)),
    #("duration_ns", json.int(entry.duration_ns)),
    #("ip", json.nullable(entry.ip, json.string)),
    #("user_agent", json.nullable(entry.user_agent, json.string)),
    #("referrer", json.nullable(entry.referrer, json.string)),
    #(
      "info",
      json.nullable(
        entry.info |> dict_helpers.non_empty_dict,
        log.encode_fields,
      ),
    ),
    #(
      "warnings",
      json.nullable(
        entry.warnings |> dict_helpers.non_empty_dict,
        log.encode_fields,
      ),
    ),
    #(
      "debug",
      json.nullable(
        entry.debug |> dict_helpers.non_empty_dict,
        log.encode_fields,
      ),
    ),
    #("error", json.nullable(entry.error, encode_error)),
    #(
      "effects",
      json.nullable(
        entry.effects |> list_helpers.non_empty_list,
        effect_trace.encode_effect_measurements,
      ),
    ),
  ])
}

fn encode_pageview_log_entry(entry: pageview_entry.Entry) -> json.Json {
  json.object([
    #("id", json.string(uuid.to_string(entry.id))),
    #(
      "created_at",
      json.string(timestamp.to_rfc3339(entry.created_at, calendar.utc_offset)),
    ),
    #(
      "session_id",
      json.nullable(entry.session_id, fn(id) { json.string(uuid.to_string(id)) }),
    ),
    #(
      "user_id",
      json.nullable(entry.user_id, fn(id) { json.string(uuid.to_string(id)) }),
    ),
    #("route", json.string(entry.route)),
    #("path", json.string(entry.path)),
    #("user_agent", json.nullable(entry.user_agent, json.string)),
    #("ip", json.nullable(entry.ip, json.string)),
  ])
}
