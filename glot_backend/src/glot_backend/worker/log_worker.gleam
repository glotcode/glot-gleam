import gleam/erlang/process
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/otp/actor
import gleam/otp/supervision
import gleam/result
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/helpers/db_helpers
import glot_backend/log
import glot_backend/sql
import glot_core/api_action.{type ApiAction}
import glot_core/helpers/dict_helpers
import glot_core/helpers/list_helpers
import pog
import wisp
import youid/uuid.{type Uuid}

pub type ApiLogEntry {
  ApiLogEntry(
    id: Uuid,
    request_id: Uuid,
    created_at: Timestamp,
    action: ApiAction,
    body_bytes: Int,
    duration_ns: Int,
    ip: Option(String),
    user_agent: Option(String),
    info: log.Fields,
    warnings: log.Fields,
    debug: log.Fields,
    error: Option(error.Error),
    effects: List(effect_trace.EffectMeasurement),
  )
}

pub type PageLogEntry {
  PageLogEntry(
    id: Uuid,
    request_id: Uuid,
    created_at: Timestamp,
    route: String,
    path: String,
    status_code: Int,
    render_mode: String,
    duration_ns: Int,
    ip: Option(String),
    user_agent: Option(String),
    referrer: Option(String),
    info: log.Fields,
    warnings: log.Fields,
    debug: log.Fields,
    error: Option(error.Error),
    effects: List(effect_trace.EffectMeasurement),
  )
}

pub type PageviewLogEntry {
  PageviewLogEntry(
    id: Uuid,
    created_at: Timestamp,
    session_id: Option(Uuid),
    user_id: Option(Uuid),
    route: String,
    path: String,
    user_agent: Option(String),
    ip: Option(String),
  )
}

pub type Message {
  Insert(ApiLogEntry)
  InsertPage(PageLogEntry)
  InsertPageview(PageviewLogEntry)
  Tick
  Drain(reply: process.Subject(Nil))
}

type PendingEntry {
  PendingApiLogEntry(ApiLogEntry)
  PendingPageLogEntry(PageLogEntry)
  PendingPageviewLogEntry(PageviewLogEntry)
}

type State {
  State(
    subject: process.Subject(Message),
    db: pog.Connection,
    pending_entries: List(PendingEntry),
    pending_count: Int,
    flush_scheduled: Bool,
  )
}

const call_timeout_ms = 5000

const flush_interval_ms = 5000

const max_batch_size = 100

const max_buffer_size = 1000

pub fn start(name: process.Name(Message), db: pog.Connection) {
  actor.new_with_initialiser(1000, fn(subject) {
    let initial_state =
      State(
        subject: subject,
        db: db,
        pending_entries: [],
        pending_count: 0,
        flush_scheduled: False,
      )
    let initialised = actor.initialised(initial_state)
    Ok(actor.returning(initialised, Nil))
  })
  |> actor.named(name)
  |> actor.on_message(handle_message)
  |> actor.start
}

pub fn supervised(name: process.Name(Message), db: pog.Connection) {
  supervision.worker(fn() { start(name, db) })
}

pub fn drain(subject: process.Subject(Message)) -> Nil {
  process.call(subject, call_timeout_ms, Drain)
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    Insert(log_entry) -> {
      let state =
        state
        |> enqueue_entry(PendingApiLogEntry(log_entry))
        |> schedule_flush_if_needed()

      case state.pending_count >= max_batch_size {
        True -> actor.continue(flush_entries_runtime(state))
        False -> actor.continue(state)
      }
    }
    InsertPage(log_entry) -> {
      let state =
        state
        |> enqueue_entry(PendingPageLogEntry(log_entry))
        |> schedule_flush_if_needed()

      case state.pending_count >= max_batch_size {
        True -> actor.continue(flush_entries_runtime(state))
        False -> actor.continue(state)
      }
    }
    InsertPageview(log_entry) -> {
      let state =
        state
        |> enqueue_entry(PendingPageviewLogEntry(log_entry))
        |> schedule_flush_if_needed()

      case state.pending_count >= max_batch_size {
        True -> actor.continue(flush_entries_runtime(state))
        False -> actor.continue(state)
      }
    }
    Tick -> {
      let state = State(..state, flush_scheduled: False)
      actor.continue(flush_entries_runtime(state))
    }
    Drain(reply) -> {
      // `process.call` only reaches this point after earlier inserts in the
      // mailbox have been processed, so flushing here acts as an idle barrier.
      let state = flush_entries_for_shutdown(state)
      process.send(reply, Nil)
      actor.continue(state)
    }
  }
}

fn enqueue_entry(state: State, entry: PendingEntry) -> State {
  case state.pending_count >= max_buffer_size {
    True ->
      State(..state, pending_entries: [
        entry,
        ..drop_oldest_entry(state.pending_entries)
      ])
    False ->
      State(
        ..state,
        pending_entries: [entry, ..state.pending_entries],
        pending_count: state.pending_count + 1,
      )
  }
}

fn drop_oldest_entry(entries: List(PendingEntry)) -> List(PendingEntry) {
  case list.reverse(entries) {
    [] -> []
    [_oldest, ..rest] -> list.reverse(rest)
  }
}

fn schedule_flush_if_needed(state: State) -> State {
  case state.pending_count > 0 && !state.flush_scheduled {
    True -> {
      let _ = process.send_after(state.subject, flush_interval_ms, Tick)
      State(..state, flush_scheduled: True)
    }
    False -> state
  }
}

fn flush_entries_runtime(state: State) -> State {
  case state.pending_entries {
    [] -> State(..state, flush_scheduled: False)
    pending_entries -> {
      case insert_logs(state.db, list.reverse(pending_entries)) {
        Ok(_) ->
          State(
            ..state,
            pending_entries: [],
            pending_count: 0,
            flush_scheduled: False,
          )
        Error(err) -> {
          wisp.log_error("Failed to insert log entry batch: " <> err)
          schedule_flush_if_needed(state)
        }
      }
    }
  }
}

fn flush_entries_for_shutdown(state: State) -> State {
  case state.pending_entries {
    [] -> State(..state, flush_scheduled: False)
    pending_entries -> {
      case insert_logs(state.db, list.reverse(pending_entries)) {
        Ok(_) -> {
          State(
            ..state,
            pending_entries: [],
            pending_count: 0,
            flush_scheduled: False,
          )
        }
        Error(err) -> {
          wisp.log_error(
            "Failed to insert log entry batch during shutdown: " <> err,
          )
          State(
            ..state,
            pending_entries: [],
            pending_count: 0,
            flush_scheduled: False,
          )
        }
      }
    }
  }
}

fn insert_logs(
  db: pog.Connection,
  entries: List(PendingEntry),
) -> Result(Nil, String) {
  let #(api_entries, page_entries, pageview_entries) =
    split_entries(entries, [], [], [])
  pog.transaction(db, fn(connection) {
    use _ <- result.try(insert_api_logs(connection, api_entries))
    use _ <- result.try(insert_page_logs(connection, page_entries))
    insert_pageview_logs(connection, pageview_entries)
  })
  |> result.map_error(fn(err) { string.inspect(err) })
}

fn split_entries(
  entries: List(PendingEntry),
  api_entries: List(ApiLogEntry),
  page_entries: List(PageLogEntry),
  pageview_entries: List(PageviewLogEntry),
) -> #(List(ApiLogEntry), List(PageLogEntry), List(PageviewLogEntry)) {
  case entries {
    [] -> #(
      list.reverse(api_entries),
      list.reverse(page_entries),
      list.reverse(pageview_entries),
    )
    [PendingApiLogEntry(entry), ..rest] ->
      split_entries(
        rest,
        [entry, ..api_entries],
        page_entries,
        pageview_entries,
      )
    [PendingPageLogEntry(entry), ..rest] ->
      split_entries(
        rest,
        api_entries,
        [entry, ..page_entries],
        pageview_entries,
      )
    [PendingPageviewLogEntry(entry), ..rest] ->
      split_entries(rest, api_entries, page_entries, [entry, ..pageview_entries])
  }
}

fn insert_api_logs(
  db: pog.Connection,
  entries: List(ApiLogEntry),
) -> Result(Nil, String) {
  case entries {
    [] -> Ok(Nil)
    _ -> {
      let query =
        sql.insert_api_log(
          entries: json.array(entries, of: encode_api_log_entry)
          |> json.to_string,
        )

      let res =
        db_helpers.execute(db_helpers.new(db), query, fn(err) {
          string.inspect(err)
        })

      case res {
        Ok(_) -> Ok(Nil)
        Error(err) -> Error(err)
      }
    }
  }
}

fn insert_page_logs(
  db: pog.Connection,
  entries: List(PageLogEntry),
) -> Result(Nil, String) {
  case entries {
    [] -> Ok(Nil)
    _ -> {
      let query =
        sql.insert_page_log(
          entries: json.array(entries, of: encode_page_log_entry)
          |> json.to_string,
        )

      let res =
        db_helpers.execute(db_helpers.new(db), query, fn(err) {
          string.inspect(err)
        })

      case res {
        Ok(_) -> Ok(Nil)
        Error(err) -> Error(err)
      }
    }
  }
}

fn insert_pageview_logs(
  db: pog.Connection,
  entries: List(PageviewLogEntry),
) -> Result(Nil, String) {
  case entries {
    [] -> Ok(Nil)
    _ -> {
      let query =
        sql.insert_pageview_log(
          entries: json.array(entries, of: encode_pageview_log_entry)
          |> json.to_string,
        )

      let res =
        db_helpers.execute(db_helpers.new(db), query, fn(err) {
          string.inspect(err)
        })

      case res {
        Ok(_) -> Ok(Nil)
        Error(err) -> Error(err)
      }
    }
  }
}

fn encode_error(err: error.Error) -> json.Json {
  json.object([
    #("message", json.string(error.to_string(err))),
  ])
}

fn encode_api_log_entry(entry: ApiLogEntry) -> json.Json {
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
        entry.info
          |> dict_helpers.non_empty_dict,
        log.encode_fields,
      ),
    ),
    #(
      "warnings",
      json.nullable(
        entry.warnings
          |> dict_helpers.non_empty_dict,
        log.encode_fields,
      ),
    ),
    #(
      "debug",
      json.nullable(
        entry.debug
          |> dict_helpers.non_empty_dict,
        log.encode_fields,
      ),
    ),
    #("error", json.nullable(entry.error, encode_error)),
    #(
      "effects",
      json.nullable(
        entry.effects
          |> list_helpers.non_empty_list,
        effect_trace.encode_effect_measurements,
      ),
    ),
  ])
}

fn encode_page_log_entry(entry: PageLogEntry) -> json.Json {
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
        entry.info
          |> dict_helpers.non_empty_dict,
        log.encode_fields,
      ),
    ),
    #(
      "warnings",
      json.nullable(
        entry.warnings
          |> dict_helpers.non_empty_dict,
        log.encode_fields,
      ),
    ),
    #(
      "debug",
      json.nullable(
        entry.debug
          |> dict_helpers.non_empty_dict,
        log.encode_fields,
      ),
    ),
    #("error", json.nullable(entry.error, encode_error)),
    #(
      "effects",
      json.nullable(
        entry.effects
          |> list_helpers.non_empty_list,
        effect_trace.encode_effect_measurements,
      ),
    ),
  ])
}

fn encode_pageview_log_entry(entry: PageviewLogEntry) -> json.Json {
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
